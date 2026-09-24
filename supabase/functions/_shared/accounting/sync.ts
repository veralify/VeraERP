// The sync worker's logic, independent of Supabase so it can be tested with
// an in-memory store.
//
// Design: a job says *which* transaction changed, not what to send. The
// worker always reconciles the provider with the transaction's current state
// (exists and in scope → create or update; otherwise → delete), and it keys
// everything on accounting_links. That makes every job idempotent: a retry
// after a crash, a duplicate job, or jobs processed out of order all converge
// on the same provider record instead of creating duplicates.

import {
  buildExpenseDraft,
  type MappingRow,
  type ReceiptRow,
  type TransactionRow,
} from './draft.ts';
import {
  type AccountingAdapter,
  AccountingError,
  type ConnectionContext,
  type ExternalRecord,
  type ReceiptFile,
  type TokenBundle,
} from './types.ts';

/** Retry schedule after the 1st…5th failure; the 6th failure is final (`dead`). */
export const BACKOFF_SECONDS = [60, 5 * 60, 30 * 60, 2 * 60 * 60, 12 * 60 * 60] as const;

/** Refresh an access token this long before it expires. */
export const REFRESH_MARGIN_MS = 2 * 60 * 1000;

export type JobStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'dead';

export interface SyncJob {
  id: string;
  user_id: string;
  connection_id: string;
  transaction_id: string;
  action: 'create' | 'update' | 'delete';
  status: JobStatus;
  attempts: number;
  next_attempt_at: string;
  last_error: string | null;
}

export interface ConnectionRow {
  id: string;
  user_id: string;
  provider: AccountingAdapter['provider'];
  external_company_id: string;
  status: 'active' | 'needs_reauth' | 'revoked' | 'error';
  sync_scope: 'personal' | 'business';
  auto_sync: boolean;
}

export interface LinkRow {
  transaction_id: string;
  connection_id: string;
  user_id: string;
  external_id: string;
  external_type: string;
  attachment_external_id: string | null;
  synced_at?: string;
}

export interface TokenRecord {
  secretId: string;
  tokens: TokenBundle;
}

export interface JobPatch {
  status: JobStatus;
  attempts?: number;
  next_attempt_at?: string;
  locked_at: null;
  last_error: string | null;
}

export interface ConnectionPatch {
  status?: ConnectionRow['status'];
  last_error?: string | null;
  last_synced_at?: string;
}

/** Everything the worker reads and writes, behind one seam. */
export interface SyncStore {
  loadConnection(connectionId: string): Promise<ConnectionRow | null>;
  readTokens(connectionId: string): Promise<TokenRecord | null>;
  /** Compare-and-swap on the Vault secret; resolves to the new secret id, or null if another worker got there first. */
  replaceTokens(previousSecretId: string, tokens: TokenBundle): Promise<string | null>;
  /** Flags every connection that shares the secret: one dead grant affects them all. */
  markNeedsReauth(secretId: string | null, connectionId: string, message: string): Promise<void>;
  updateConnection(connectionId: string, patch: ConnectionPatch): Promise<void>;
  loadTransaction(transactionId: string): Promise<TransactionRow | null>;
  loadMappings(connectionId: string): Promise<MappingRow[]>;
  loadReceipt(receiptId: string, userId: string): Promise<ReceiptRow | null>;
  downloadReceiptPage(path: string, fileName: string): Promise<ReceiptFile>;
  getLink(transactionId: string, connectionId: string): Promise<LinkRow | null>;
  saveLink(link: LinkRow): Promise<void>;
  deleteLink(transactionId: string, connectionId: string): Promise<void>;
  updateJob(jobId: string, patch: JobPatch): Promise<void>;
}

export function toAccountingError(error: unknown): AccountingError {
  if (error instanceof AccountingError) return error;
  const message = error instanceof Error ? error.message : String(error);
  // Unknown failures (a database hiccup, a bug) are retried, not dropped.
  return new AccountingError('transient', message);
}

/** The job update after a failed attempt. */
export function failurePatch(
  job: Pick<SyncJob, 'attempts'>,
  error: AccountingError,
  now = new Date(),
): JobPatch {
  const attempts = job.attempts + 1;
  const message = error.message.slice(0, 1000);
  // The provider rejected this exact payload; sending it again cannot work.
  // A later edit of the transaction enqueues a fresh job.
  if (!error.retryable || attempts > BACKOFF_SECONDS.length) {
    return { status: 'dead', attempts, locked_at: null, last_error: message };
  }
  const delay = Math.max(BACKOFF_SECONDS[attempts - 1], error.retryAfterSeconds ?? 0);
  return {
    status: 'failed',
    attempts,
    next_attempt_at: new Date(now.getTime() + delay * 1000).toISOString(),
    locked_at: null,
    last_error: message,
  };
}

/** Puts a job back in the queue without spending an attempt (reauth, rate limit on a sibling). */
export function releasePatch(message: string | null, notBefore?: Date): JobPatch {
  return {
    status: 'pending',
    locked_at: null,
    last_error: message,
    ...(notBefore ? { next_attempt_at: notBefore.toISOString() } : {}),
  };
}

export function needsRefresh(tokens: TokenBundle, now: Date): boolean {
  const expires = Date.parse(tokens.expires_at);
  return !Number.isFinite(expires) || expires - REFRESH_MARGIN_MS <= now.getTime();
}

/**
 * Hands out a usable access token for one connection, refreshing it when it
 * is about to expire (or when the provider just said 401). Refreshes are
 * stored immediately: Xero and QuickBooks rotate refresh tokens, so losing a
 * refreshed bundle would strand the connection.
 */
export class TokenManager {
  private record: TokenRecord | null = null;

  constructor(
    private readonly store: SyncStore,
    private readonly adapter: AccountingAdapter,
    private readonly connection: ConnectionRow,
    private readonly now: () => Date = () => new Date(),
  ) {}

  get secretId(): string | null {
    return this.record?.secretId ?? null;
  }

  async context(force = false): Promise<ConnectionContext> {
    return { companyId: this.connection.external_company_id, tokens: await this.tokens(force) };
  }

  async tokens(force = false): Promise<TokenBundle> {
    if (!this.record) {
      this.record = await this.store.readTokens(this.connection.id);
      if (!this.record) {
        await this.fail(new AccountingError('auth', 'No stored token for this connection'));
      }
    }
    const current = this.record!;
    if (!force && !needsRefresh(current.tokens, this.now())) return current.tokens;

    // Another worker (or accounting-accounts) may have refreshed meanwhile.
    const latest = await this.store.readTokens(this.connection.id);
    if (latest && latest.secretId !== current.secretId) {
      this.record = latest;
      if (!needsRefresh(latest.tokens, this.now())) return latest.tokens;
    }

    let refreshed: TokenBundle;
    try {
      refreshed = await this.adapter.refresh(this.record!.tokens);
    } catch (error) {
      const failure = toAccountingError(error);
      if (failure.kind === 'auth') await this.fail(failure);
      throw failure;
    }
    const newId = await this.store.replaceTokens(this.record!.secretId, refreshed);
    if (!newId) {
      // Lost the race: someone stored a newer bundle; use theirs.
      const winner = await this.store.readTokens(this.connection.id);
      if (!winner) await this.fail(new AccountingError('auth', 'Token disappeared during refresh'));
      this.record = winner!;
      return winner!.tokens;
    }
    this.record = { secretId: newId, tokens: refreshed };
    return refreshed;
  }

  /** Marks the connection (and any sharing the grant) as needing a new consent, then throws. */
  async fail(error: AccountingError): Promise<never> {
    await this.store.markNeedsReauth(
      this.secretId,
      this.connection.id,
      error.message.slice(0, 1000),
    );
    throw new AccountingError('auth', error.message, {
      status: error.status,
      provider: this.adapter.provider,
    });
  }

  /**
   * Runs a provider call; on 401 refreshes once and retries. A second 401
   * (or a refresh that fails) means the grant is gone.
   */
  async call<T>(operation: (ctx: ConnectionContext) => Promise<T>): Promise<T> {
    try {
      return await operation(await this.context());
    } catch (error) {
      if (!(error instanceof AccountingError) || error.kind !== 'auth') throw error;
    }
    const ctx = await this.context(true);
    try {
      return await operation(ctx);
    } catch (error) {
      if (error instanceof AccountingError && error.kind === 'auth') return await this.fail(error);
      throw error;
    }
  }
}

export interface WorkerDeps {
  store: SyncStore;
  adapter: AccountingAdapter;
  now?: () => Date;
}

export type JobOutcome =
  | {
    id: string;
    status: 'succeeded';
    result: 'created' | 'updated' | 'deleted' | 'skipped';
    warning?: string;
  }
  | { id: string; status: 'failed' | 'dead' | 'pending'; error: string };

function isWanted(tx: TransactionRow | null, connection: ConnectionRow): tx is TransactionRow {
  return !!tx && tx.user_id === connection.user_id && tx.deleted_at === null &&
    tx.direction === 'expense' && tx.scope === connection.sync_scope;
}

function record(link: LinkRow): ExternalRecord {
  return { externalId: link.external_id, externalType: link.external_type };
}

function pageFileName(transactionId: string, path: string, index: number): string {
  const extension = /\.([a-z0-9]+)$/i.exec(path)?.[1]?.toLowerCase() ?? 'jpg';
  return `receipt-${transactionId.slice(0, 8)}-${index + 1}.${extension}`;
}

/**
 * Brings the provider in line with one transaction. Returns what happened.
 * Throws AccountingError on failure; the caller turns that into a job patch.
 */
export async function reconcileTransaction(
  deps: WorkerDeps,
  tokens: TokenManager,
  connection: ConnectionRow,
  transactionId: string,
  /** Collects problems that do not fail the job (a receipt the provider refused). */
  warnings: string[] = [],
): Promise<'created' | 'updated' | 'deleted' | 'skipped'> {
  const { store, adapter } = deps;
  const now = deps.now ?? (() => new Date());
  const tx = await store.loadTransaction(transactionId);
  const link = await store.getLink(transactionId, connection.id);

  if (!isWanted(tx, connection)) {
    if (!link) return 'skipped';
    try {
      await tokens.call((ctx) => adapter.deleteExpense(ctx, record(link)));
    } catch (error) {
      // Already gone at the provider (deleted by the bookkeeper): nothing left to do.
      if (!(error instanceof AccountingError) || error.kind !== 'not_found') throw error;
    }
    await store.deleteLink(transactionId, connection.id);
    return 'deleted';
  }

  const [mappings, receipt] = await Promise.all([
    store.loadMappings(connection.id),
    tx.receipt_id ? store.loadReceipt(tx.receipt_id, tx.user_id) : Promise.resolve(null),
  ]);
  const draft = buildExpenseDraft(tx, mappings, receipt, adapter);

  let current: LinkRow;
  let result: 'created' | 'updated';
  if (link) {
    try {
      const updated = await tokens.call((ctx) => adapter.updateExpense(ctx, record(link), draft));
      current = { ...link, external_id: updated.externalId, external_type: updated.externalType };
      result = 'updated';
    } catch (error) {
      if (!(error instanceof AccountingError) || error.kind !== 'not_found') throw error;
      // Deleted on the provider side while still live here: recreate it.
      const created = await tokens.call((ctx) => adapter.createExpense(ctx, draft));
      current = {
        ...link,
        external_id: created.externalId,
        external_type: created.externalType,
        attachment_external_id: null,
      };
      result = 'created';
    }
  } else {
    const created = await tokens.call((ctx) => adapter.createExpense(ctx, draft));
    current = {
      transaction_id: tx.id,
      connection_id: connection.id,
      user_id: tx.user_id,
      external_id: created.externalId,
      external_type: created.externalType,
      attachment_external_id: null,
    };
    result = 'created';
  }
  // Link first, attachments second: if an upload fails, the retry updates
  // this record instead of creating a second one.
  current.synced_at = now().toISOString();
  await store.saveLink(current);

  const pages = (receipt?.image_paths ?? []).slice(0, adapter.maxAttachments);
  const uploaded = current.attachment_external_id
    ? current.attachment_external_id.split(',').filter(Boolean)
    : [];
  for (let index = uploaded.length; index < pages.length; index++) {
    const file = await store.downloadReceiptPage(
      pages[index],
      pageFileName(tx.id, pages[index], index),
    );
    let id: string;
    try {
      id = await tokens.call((ctx) => adapter.attachReceipt(ctx, record(current), file));
    } catch (error) {
      // The expense itself is booked; a receipt the provider will never take
      // (type, size) is reported instead of failing — and later re-sending —
      // the whole record.
      if (error instanceof AccountingError && error.kind === 'permanent') {
        warnings.push(`Receipt not attached: ${error.message}`);
        break;
      }
      throw error;
    }
    uploaded.push(id.replaceAll(',', '_'));
    // Saved per page, so a retry resumes after the last page that made it.
    current = {
      ...current,
      attachment_external_id: uploaded.join(','),
      synced_at: now().toISOString(),
    };
    await store.saveLink(current);
  }
  return result;
}

/** Claimed jobs per connection, keeping the claim's order inside each group. */
export function groupByConnection(jobs: SyncJob[]): Map<string, SyncJob[]> {
  const groups = new Map<string, SyncJob[]>();
  for (const job of jobs) {
    const list = groups.get(job.connection_id) ?? [];
    list.push(job);
    groups.set(job.connection_id, list);
  }
  return groups;
}

/**
 * Processes the claimed jobs of one connection in order. The claim function
 * never hands two workers jobs that share a token, so refreshes here cannot
 * race another worker's.
 */
export async function processConnectionJobs(
  deps: WorkerDeps,
  connectionId: string,
  jobs: SyncJob[],
): Promise<JobOutcome[]> {
  const { store } = deps;
  const now = deps.now ?? (() => new Date());
  const outcomes: JobOutcome[] = [];
  const connection = await store.loadConnection(connectionId);

  const releaseAll = async (rest: SyncJob[], message: string, notBefore?: Date) => {
    for (const job of rest) {
      await store.updateJob(job.id, releasePatch(message, notBefore));
      outcomes.push({ id: job.id, status: 'pending', error: message });
    }
  };

  if (!connection || connection.status !== 'active' || !connection.auto_sync) {
    // Paused or disconnected after the claim: leave the work queued for later.
    await releaseAll(
      jobs,
      connection
        ? `Connection is ${connection.status === 'active' ? 'paused' : connection.status}`
        : 'Connection not found',
    );
    return outcomes;
  }

  const tokens = new TokenManager(store, deps.adapter, connection, now);
  for (let i = 0; i < jobs.length; i++) {
    const job = jobs[i];
    try {
      const warnings: string[] = [];
      const result = await reconcileTransaction(
        deps,
        tokens,
        connection,
        job.transaction_id,
        warnings,
      );
      const warning = warnings.length ? warnings.join('; ').slice(0, 1000) : null;
      await store.updateJob(job.id, {
        status: 'succeeded',
        locked_at: null,
        last_error: warning,
      });
      await store.updateConnection(connection.id, {
        last_synced_at: now().toISOString(),
        last_error: warning,
      });
      outcomes.push(
        warning
          ? { id: job.id, status: 'succeeded', result, warning }
          : { id: job.id, status: 'succeeded', result },
      );
    } catch (caught) {
      const error = toAccountingError(caught);
      if (error.kind === 'auth') {
        // The connection now needs a new consent; nothing else can go out.
        await releaseAll(jobs.slice(i), error.message);
        break;
      }
      const patch = failurePatch(job, error, now());
      await store.updateJob(job.id, patch);
      await store.updateConnection(connection.id, { last_error: error.message.slice(0, 1000) });
      outcomes.push({
        id: job.id,
        status: patch.status as 'failed' | 'dead',
        error: error.message,
      });
      if (error.kind === 'rate_limited') {
        // Every other call would be throttled too; wait out the window.
        const wait = Math.max(error.retryAfterSeconds ?? 60, 1);
        await releaseAll(jobs.slice(i + 1), error.message, new Date(now().getTime() + wait * 1000));
        break;
      }
    }
  }
  return outcomes;
}
