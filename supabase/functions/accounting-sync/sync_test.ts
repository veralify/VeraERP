// Worker tests: backoff, idempotency (links → update, never a duplicate
// create), token refresh and re-authorisation, attachments, deletes.

import { assert, assertEquals } from 'jsr:@std/assert@1';
import type { MappingRow, ReceiptRow, TransactionRow } from '../_shared/accounting/draft.ts';
import {
  BACKOFF_SECONDS,
  type ConnectionPatch,
  type ConnectionRow,
  failurePatch,
  groupByConnection,
  type JobPatch,
  type LinkRow,
  processConnectionJobs,
  type SyncJob,
  type SyncStore,
  type TokenRecord,
} from '../_shared/accounting/sync.ts';
import {
  type AccountingAdapter,
  AccountingError,
  type ConnectionContext,
  type ExpenseDraft,
  type ExternalRecord,
  type ReceiptFile,
  type TokenBundle,
} from '../_shared/accounting/types.ts';

const NOW = new Date('2026-09-24T12:00:00Z');
const USER = 'u-1';
const TX = 'a3200000-0000-0000-0000-000000000001';

function tokens(overrides: Partial<TokenBundle> = {}): TokenBundle {
  return {
    access_token: 'at-1',
    refresh_token: 'rt-1',
    expires_at: '2026-09-24T13:00:00Z',
    ...overrides,
  };
}

class MemoryStore implements SyncStore {
  connection: ConnectionRow = {
    id: 'c-1',
    user_id: USER,
    provider: 'xero',
    external_company_id: 'tenant-1',
    status: 'active',
    sync_scope: 'business',
    auto_sync: true,
  };
  connectionPatches: ConnectionPatch[] = [];
  token: TokenRecord | null = { secretId: 's-1', tokens: tokens() };
  transactions = new Map<string, TransactionRow>();
  mappings: MappingRow[] = [
    { kind: 'category', local_key: 'default', external_id: '429' },
    { kind: 'tax_rate', local_key: '20', external_id: 'INPUT2' },
    { kind: 'payment_account', local_key: 'default', external_id: 'bank-1' },
  ];
  receipts = new Map<string, ReceiptRow>();
  links = new Map<string, LinkRow>();
  jobPatches = new Map<string, JobPatch>();
  downloads: string[] = [];
  reauth: string[] = [];

  loadConnection() {
    return Promise.resolve({ ...this.connection });
  }
  readTokens() {
    return Promise.resolve(this.token ? { ...this.token } : null);
  }
  replaceTokens(previous: string, bundle: TokenBundle) {
    if (this.token?.secretId !== previous) return Promise.resolve(null);
    const id = `${previous}+`;
    this.token = { secretId: id, tokens: bundle };
    return Promise.resolve(id);
  }
  markNeedsReauth(_secretId: string | null, _connectionId: string, message: string) {
    this.connection.status = 'needs_reauth';
    this.reauth.push(message);
    return Promise.resolve();
  }
  updateConnection(_id: string, patch: ConnectionPatch) {
    this.connectionPatches.push(patch);
    return Promise.resolve();
  }
  loadTransaction(id: string) {
    return Promise.resolve(this.transactions.get(id) ?? null);
  }
  loadMappings() {
    return Promise.resolve(this.mappings);
  }
  loadReceipt(id: string) {
    return Promise.resolve(this.receipts.get(id) ?? null);
  }
  downloadReceiptPage(path: string, fileName: string): Promise<ReceiptFile> {
    this.downloads.push(path);
    return Promise.resolve({ fileName, contentType: 'image/jpeg', bytes: new Uint8Array([1, 2]) });
  }
  getLink(transactionId: string, connectionId: string) {
    const link = this.links.get(`${transactionId}|${connectionId}`);
    return Promise.resolve(link ? { ...link } : null);
  }
  saveLink(link: LinkRow) {
    this.links.set(`${link.transaction_id}|${link.connection_id}`, { ...link });
    return Promise.resolve();
  }
  deleteLink(transactionId: string, connectionId: string) {
    this.links.delete(`${transactionId}|${connectionId}`);
    return Promise.resolve();
  }
  updateJob(id: string, patch: JobPatch) {
    this.jobPatches.set(id, patch);
    return Promise.resolve();
  }
}

type Call = { op: string; token: string; record?: ExternalRecord; draft?: ExpenseDraft };

/** An adapter whose provider behaviour each test scripts. */
class FakeAdapter implements AccountingAdapter {
  readonly provider = 'xero' as const;
  readonly supportsPkce = true;
  readonly requiresPaymentAccount = false;
  readonly maxAttachments = 10;
  calls: Call[] = [];
  refreshes = 0;
  nextId = 1;
  /** Throw this from the named operation, once per entry. */
  failures: Partial<Record<string, AccountingError[]>> = {};
  refreshResult: () => Promise<TokenBundle> = () =>
    Promise.resolve(
      tokens({ access_token: `at-refreshed-${this.refreshes}`, refresh_token: 'rt-2' }),
    );

  private run<T>(op: string, ctx: ConnectionContext, value: () => T, extra: Partial<Call> = {}) {
    this.calls.push({ op, token: ctx.tokens.access_token, ...extra });
    const failure = this.failures[op]?.shift();
    return failure ? Promise.reject(failure) : Promise.resolve(value());
  }

  authorizeUrl() {
    return 'https://example.test';
  }
  exchangeCode() {
    return Promise.resolve(tokens());
  }
  refresh(): Promise<TokenBundle> {
    this.refreshes++;
    return this.refreshResult();
  }
  revoke() {
    return Promise.resolve();
  }
  listCompanies() {
    return Promise.resolve([]);
  }
  listExpenseAccounts() {
    return Promise.resolve([]);
  }
  listTaxCodes() {
    return Promise.resolve([]);
  }
  listPaymentAccounts() {
    return Promise.resolve([]);
  }
  createExpense(ctx: ConnectionContext, draft: ExpenseDraft) {
    return this.run(
      'create',
      ctx,
      () => ({ externalId: `bt-${this.nextId++}`, externalType: 'SPEND' }),
      { draft },
    );
  }
  updateExpense(ctx: ConnectionContext, record: ExternalRecord, draft: ExpenseDraft) {
    return this.run('update', ctx, () => record, { record, draft });
  }
  deleteExpense(ctx: ConnectionContext, record: ExternalRecord) {
    return this.run('delete', ctx, () => undefined, { record });
  }
  attachReceipt(ctx: ConnectionContext, record: ExternalRecord, file: ReceiptFile) {
    return this.run('attach', ctx, () => `att-${file.fileName}`, { record });
  }
}

function expense(overrides: Partial<TransactionRow> = {}): TransactionRow {
  return {
    id: TX,
    user_id: USER,
    transaction_date: '2026-09-20',
    merchant: 'Staples',
    amount: 24,
    direction: 'expense',
    category: 'office_supplies',
    notes: '',
    currency: 'GBP',
    tax_amount: 4,
    scope: 'business',
    receipt_id: null,
    deleted_at: null,
    ...overrides,
  };
}

function job(overrides: Partial<SyncJob> = {}): SyncJob {
  return {
    id: 'j-1',
    user_id: USER,
    connection_id: 'c-1',
    transaction_id: TX,
    action: 'create',
    status: 'running',
    attempts: 0,
    next_attempt_at: NOW.toISOString(),
    last_error: null,
    ...overrides,
  };
}

function setup() {
  const store = new MemoryStore();
  const adapter = new FakeAdapter();
  const run = (jobs: SyncJob[]) =>
    processConnectionJobs({ store, adapter, now: () => NOW }, 'c-1', jobs);
  return { store, adapter, run };
}

Deno.test('backoff: 1m, 5m, 30m, 2h, 12h, then dead', () => {
  const error = new AccountingError('transient', 'boom');
  const delays = [0, 1, 2, 3, 4].map((attempts) => {
    const patch = failurePatch({ attempts }, error, NOW);
    assertEquals(patch.status, 'failed');
    assertEquals(patch.attempts, attempts + 1);
    return (Date.parse(patch.next_attempt_at!) - NOW.getTime()) / 1000;
  });
  assertEquals(delays, [...BACKOFF_SECONDS]);
  assertEquals(delays, [60, 300, 1800, 7200, 43200]);
  const last = failurePatch({ attempts: 5 }, error, NOW);
  assertEquals(last.status, 'dead');
  assertEquals(last.attempts, 6);
});

Deno.test('backoff: a longer Retry-After wins; a permanent error is dead at once', () => {
  const limited = failurePatch(
    { attempts: 0 },
    new AccountingError('rate_limited', 'slow down', { retryAfterSeconds: 600 }),
    NOW,
  );
  assertEquals(Date.parse(limited.next_attempt_at!) - NOW.getTime(), 600_000);
  const rejected = failurePatch(
    { attempts: 0 },
    new AccountingError('permanent', 'bad account'),
    NOW,
  );
  assertEquals(rejected.status, 'dead');
});

Deno.test('worker: a new expense is created, linked and its receipt pages attached', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense({ receipt_id: 'r-1' }));
  store.receipts.set('r-1', {
    id: 'r-1',
    image_paths: [`${USER}/r-1/1.jpg`, `${USER}/r-1/2.jpg`],
    extraction: null,
  });
  const [outcome] = await run([job()]);
  assertEquals(outcome, { id: 'j-1', status: 'succeeded', result: 'created' });
  assertEquals(adapter.calls.map((c) => c.op), ['create', 'attach', 'attach']);
  const link = store.links.get(`${TX}|c-1`)!;
  assertEquals(link.external_id, 'bt-1');
  assertEquals(
    link.attachment_external_id,
    'att-receipt-a3200000-1.jpg,att-receipt-a3200000-2.jpg',
  );
  assertEquals(store.jobPatches.get('j-1')?.status, 'succeeded');
  assertEquals(store.connectionPatches.at(-1), {
    last_synced_at: NOW.toISOString(),
    last_error: null,
  });
  const draft = adapter.calls[0].draft!;
  assertEquals(draft.lines[0].accountId, '429');
  assertEquals(draft.lines[0].taxCodeId, 'INPUT2');
});

Deno.test('worker: an existing link means update, never a second create', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  store.links.set(`${TX}|c-1`, {
    transaction_id: TX,
    connection_id: 'c-1',
    user_id: USER,
    external_id: 'bt-9',
    external_type: 'SPEND',
    attachment_external_id: null,
  });
  // The job still says "create" (e.g. a retry after the link was written): the link decides.
  const [outcome] = await run([job({ action: 'create' })]);
  assertEquals(outcome.status, 'succeeded');
  assertEquals(adapter.calls.map((c) => c.op), ['update']);
  assertEquals(adapter.calls[0].record, { externalId: 'bt-9', externalType: 'SPEND' });
});

Deno.test('worker: running the same job twice creates the record once', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  await run([job()]);
  await run([job()]);
  assertEquals(adapter.calls.map((c) => c.op), ['create', 'update']);
  assertEquals(store.links.size, 1);
});

Deno.test('worker: a failed attachment resumes on retry without re-creating', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense({ receipt_id: 'r-1' }));
  store.receipts.set('r-1', { id: 'r-1', image_paths: ['p/1.jpg', 'p/2.jpg'], extraction: null });
  adapter.failures.attach = [];
  // Page 1 goes through, page 2 hits a 503.
  const originalAttach = adapter.attachReceipt.bind(adapter);
  let attachCalls = 0;
  adapter.attachReceipt = (ctx, record, file) => {
    attachCalls++;
    if (attachCalls === 2) return Promise.reject(new AccountingError('transient', 'xero 503'));
    return originalAttach(ctx, record, file);
  };
  const [first] = await run([job()]);
  assertEquals(first.status, 'failed');
  assertEquals(store.jobPatches.get('j-1')?.attempts, 1);
  assertEquals(store.links.get(`${TX}|c-1`)?.attachment_external_id, 'att-receipt-a3200000-1.jpg');

  const [second] = await run([job({ attempts: 1 })]);
  assertEquals(second.status, 'succeeded');
  assertEquals(adapter.calls.map((c) => c.op), ['create', 'attach', 'update', 'attach']);
  assertEquals(store.downloads, ['p/1.jpg', 'p/2.jpg', 'p/2.jpg']);
});

Deno.test('worker: a receipt the provider refuses is a warning, not a failed expense', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense({ receipt_id: 'r-1' }));
  store.receipts.set('r-1', { id: 'r-1', image_paths: ['p/1.heic'], extraction: null });
  adapter.failures.attach = [new AccountingError('permanent', 'image/heic not accepted')];
  const [outcome] = await run([job()]);
  assertEquals(outcome.status, 'succeeded');
  assert('warning' in outcome && outcome.warning?.includes('Receipt not attached'));
  assertEquals(store.jobPatches.get('j-1')?.status, 'succeeded');
  assert(store.jobPatches.get('j-1')?.last_error?.includes('image/heic'));
  assertEquals(store.links.get(`${TX}|c-1`)?.external_id, 'bt-1');
});

Deno.test('worker: a record deleted at the provider is recreated on update', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  store.links.set(`${TX}|c-1`, {
    transaction_id: TX,
    connection_id: 'c-1',
    user_id: USER,
    external_id: 'bt-gone',
    external_type: 'SPEND',
    attachment_external_id: 'old-att',
  });
  adapter.failures.update = [new AccountingError('not_found', 'xero 404')];
  const [outcome] = await run([job({ action: 'update' })]);
  assertEquals(outcome, { id: 'j-1', status: 'succeeded', result: 'created' });
  assertEquals(store.links.get(`${TX}|c-1`)?.external_id, 'bt-1');
  assertEquals(store.links.get(`${TX}|c-1`)?.attachment_external_id, null);
});

Deno.test('worker: a soft-deleted synced expense is deleted and unlinked', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense({ deleted_at: '2026-09-24T11:00:00Z' }));
  store.links.set(`${TX}|c-1`, {
    transaction_id: TX,
    connection_id: 'c-1',
    user_id: USER,
    external_id: 'bt-3',
    external_type: 'SPEND',
    attachment_external_id: null,
  });
  adapter.failures.delete = [new AccountingError('not_found', 'already gone')];
  const [outcome] = await run([job({ action: 'delete' })]);
  assertEquals(outcome, { id: 'j-1', status: 'succeeded', result: 'deleted' });
  assertEquals(store.links.size, 0);
});

Deno.test('worker: an unsynced expense moved out of scope is a no-op', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense({ scope: 'personal' }));
  const [outcome] = await run([job()]);
  assertEquals(outcome, { id: 'j-1', status: 'succeeded', result: 'skipped' });
  assertEquals(adapter.calls, []);
});

Deno.test('worker: 401 → refresh → retry with the new token', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  adapter.failures.create = [new AccountingError('auth', 'xero 401', { status: 401 })];
  const [outcome] = await run([job()]);
  assertEquals(outcome.status, 'succeeded');
  assertEquals(adapter.refreshes, 1);
  assertEquals(adapter.calls.map((c) => [c.op, c.token]), [
    ['create', 'at-1'],
    ['create', 'at-refreshed-1'],
  ]);
  assertEquals(store.token?.secretId, 's-1+');
  assertEquals(store.token?.tokens.refresh_token, 'rt-2');
});

Deno.test('worker: an access token about to expire is refreshed before the call', async () => {
  const { store, adapter, run } = setup();
  store.token = { secretId: 's-1', tokens: tokens({ expires_at: '2026-09-24T12:01:00Z' }) };
  store.transactions.set(TX, expense());
  await run([job()]);
  assertEquals(adapter.refreshes, 1);
  assertEquals(adapter.calls[0].token, 'at-refreshed-1');
});

Deno.test('worker: 401 after a failed refresh marks needs_reauth and requeues without spending attempts', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  store.transactions.set('tx-2', expense({ id: 'tx-2' }));
  adapter.failures.create = [new AccountingError('auth', 'xero 401', { status: 401 })];
  adapter.refreshResult = () =>
    Promise.reject(new AccountingError('auth', 'xero 400: invalid_grant'));
  const outcomes = await run([job({ attempts: 2 }), job({ id: 'j-2', transaction_id: 'tx-2' })]);
  assertEquals(store.connection.status, 'needs_reauth');
  assert(store.reauth[0].includes('invalid_grant'));
  assertEquals(outcomes.map((o) => [o.id, o.status]), [['j-1', 'pending'], ['j-2', 'pending']]);
  const patch = store.jobPatches.get('j-1')!;
  assertEquals(patch.status, 'pending');
  assertEquals(patch.attempts, undefined);
  // The second job never reached the provider.
  assertEquals(adapter.calls.length, 1);
});

Deno.test('worker: a missing mapping fails with backoff and surfaces on the connection', async () => {
  const { store, adapter, run } = setup();
  store.mappings = [];
  store.transactions.set(TX, expense());
  const [outcome] = await run([job()]);
  assertEquals(outcome.status, 'failed');
  const patch = store.jobPatches.get('j-1')!;
  assertEquals(Date.parse(patch.next_attempt_at!) - NOW.getTime(), 60_000);
  assert(store.connectionPatches.at(-1)?.last_error?.includes('No expense account'));
  assertEquals(adapter.calls, []);
});

Deno.test('worker: a rate limit holds back the rest of the batch', async () => {
  const { store, adapter, run } = setup();
  store.transactions.set(TX, expense());
  store.transactions.set('tx-2', expense({ id: 'tx-2' }));
  adapter.failures.create = [
    new AccountingError('rate_limited', 'xero 429', { status: 429, retryAfterSeconds: 120 }),
  ];
  const outcomes = await run([job(), job({ id: 'j-2', transaction_id: 'tx-2' })]);
  assertEquals(outcomes.map((o) => o.status), ['failed', 'pending']);
  assertEquals(
    store.jobPatches.get('j-2')?.next_attempt_at,
    new Date(NOW.getTime() + 120_000).toISOString(),
  );
  assertEquals(adapter.calls.length, 1);
});

Deno.test('worker: jobs of a paused connection go back to the queue untouched', async () => {
  const { store, adapter, run } = setup();
  store.connection.auto_sync = false;
  const [outcome] = await run([job({ attempts: 3 })]);
  assertEquals(outcome.status, 'pending');
  assertEquals(store.jobPatches.get('j-1'), {
    status: 'pending',
    locked_at: null,
    last_error: 'Connection is paused',
  });
  assertEquals(adapter.calls, []);
});

Deno.test('worker: claimed jobs are grouped per connection in claim order', () => {
  const groups = groupByConnection([
    job({ id: 'a', connection_id: 'c-1' }),
    job({ id: 'b', connection_id: 'c-2' }),
    job({ id: 'c', connection_id: 'c-1' }),
  ]);
  assertEquals([...groups].map(([k, v]) => [k, v.map((j) => j.id)]), [['c-1', ['a', 'c']], ['c-2', [
    'b',
  ]]]);
});
