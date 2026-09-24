// Supabase-backed SyncStore plus the Vault helpers the OAuth functions use.
//
// Tokens only move through SECURITY DEFINER functions executable by the
// service role (see 20260925130000_accounting_sync.sql): the Vault schema is
// not exposed over PostgREST, and no client role can call these functions.

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.49.8';
import type { MappingRow, ReceiptRow, TransactionRow } from './draft.ts';
import type {
  ConnectionPatch,
  ConnectionRow,
  JobPatch,
  LinkRow,
  SyncStore,
  TokenRecord,
} from './sync.ts';
import {
  AccountingError,
  type AccountingProvider,
  type ExternalCompany,
  type ReceiptFile,
  type TokenBundle,
} from './types.ts';

export const RECEIPTS_BUCKET = 'receipts';

function dbError(context: string, error: { message: string } | null): void {
  if (error) throw new AccountingError('transient', `${context}: ${error.message}`);
}

function parseBundle(secret: unknown): TokenBundle {
  try {
    const bundle = JSON.parse(String(secret)) as TokenBundle;
    if (typeof bundle.access_token !== 'string') throw new Error('no access_token');
    return bundle;
  } catch {
    throw new AccountingError('auth', 'Stored token bundle is unreadable');
  }
}

export interface StoredToken extends TokenRecord {
  /** How many *other* connections use the same secret. */
  sharedWith: number;
}

/** Reads a connection's token bundle out of Vault. */
export async function readConnectionToken(
  db: SupabaseClient,
  connectionId: string,
): Promise<StoredToken | null> {
  const { data, error } = await db.rpc('accounting_read_token', { p_connection_id: connectionId });
  dbError('accounting_read_token', error);
  const row = (Array.isArray(data) ? data[0] : data) as
    | { token_secret_id: string; secret: string; shared_with: number }
    | null
    | undefined;
  if (!row?.token_secret_id || row.secret === null || row.secret === undefined) return null;
  return {
    secretId: row.token_secret_id,
    tokens: parseBundle(row.secret),
    sharedWith: Number(row.shared_with ?? 0),
  };
}

export async function replaceConnectionToken(
  db: SupabaseClient,
  previousSecretId: string,
  tokens: TokenBundle,
): Promise<string | null> {
  const { data, error } = await db.rpc('accounting_replace_token', {
    p_old_secret_id: previousSecretId,
    p_secret: JSON.stringify(tokens),
    p_expires_at: tokens.expires_at,
  });
  dbError('accounting_replace_token', error);
  return typeof data === 'string' ? data : null;
}

/**
 * Stores a fresh grant and upserts one connection per company, atomically.
 * Re-connecting a company keeps its mappings, links and settings.
 */
export async function saveConnections(
  db: SupabaseClient,
  userId: string,
  provider: AccountingProvider,
  tokens: TokenBundle,
  companies: ExternalCompany[],
): Promise<{ connection_id: string; company_id: string; created: boolean }[]> {
  const { data, error } = await db.rpc('accounting_save_connections', {
    p_user_id: userId,
    p_provider: provider,
    p_secret: JSON.stringify(tokens),
    p_expires_at: tokens.expires_at,
    p_companies: companies.map((c) => ({
      external_company_id: c.id,
      company_name: c.name,
      country: c.country && /^[A-Z]{2}$/.test(c.country) ? c.country : null,
      home_currency: c.currency && /^[A-Z]{3}$/.test(c.currency) ? c.currency : null,
    })),
  });
  dbError('accounting_save_connections', error);
  return (data ?? []) as { connection_id: string; company_id: string; created: boolean }[];
}

/** Deletes the connection's Vault secret (unless shared) and marks it revoked. */
export async function releaseConnectionToken(
  db: SupabaseClient,
  connectionId: string,
): Promise<void> {
  const { error } = await db.rpc('accounting_release_token', { p_connection_id: connectionId });
  dbError('accounting_release_token', error);
}

const CONNECTION_COLUMNS =
  'id, user_id, provider, external_company_id, status, sync_scope, auto_sync';

export async function loadConnection(
  db: SupabaseClient,
  connectionId: string,
): Promise<ConnectionRow | null> {
  const { data, error } = await db
    .from('accounting_connections')
    .select(CONNECTION_COLUMNS)
    .eq('id', connectionId)
    .maybeSingle();
  dbError('load connection', error);
  return (data as ConnectionRow | null) ?? null;
}

export function contentTypeFor(path: string, reported?: string | null): string {
  if (reported && reported !== 'application/octet-stream') return reported;
  const extension = /\.([a-z0-9]+)$/i.exec(path)?.[1]?.toLowerCase();
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'image/jpeg';
  }
}

export class SupabaseSyncStore implements SyncStore {
  constructor(private readonly db: SupabaseClient) {}

  loadConnection(connectionId: string): Promise<ConnectionRow | null> {
    return loadConnection(this.db, connectionId);
  }

  readTokens(connectionId: string): Promise<TokenRecord | null> {
    return readConnectionToken(this.db, connectionId);
  }

  replaceTokens(previousSecretId: string, tokens: TokenBundle): Promise<string | null> {
    return replaceConnectionToken(this.db, previousSecretId, tokens);
  }

  async markNeedsReauth(
    secretId: string | null,
    connectionId: string,
    message: string,
  ): Promise<void> {
    const patch = { status: 'needs_reauth', last_error: message };
    const query = this.db.from('accounting_connections').update(patch);
    const { error } = secretId
      ? await query.eq('token_secret_id', secretId)
      : await query.eq('id', connectionId);
    dbError('mark needs_reauth', error);
  }

  async updateConnection(connectionId: string, patch: ConnectionPatch): Promise<void> {
    const { error } = await this.db.from('accounting_connections').update(patch).eq(
      'id',
      connectionId,
    );
    dbError('update connection', error);
  }

  async loadTransaction(transactionId: string): Promise<TransactionRow | null> {
    const { data, error } = await this.db
      .from('money_transactions')
      .select(
        'id, user_id, transaction_date, merchant, amount, direction, category, account, notes, currency, tax_amount, scope, receipt_id, deleted_at',
      )
      .eq('id', transactionId)
      .maybeSingle();
    dbError('load transaction', error);
    return (data as TransactionRow | null) ?? null;
  }

  async loadMappings(connectionId: string): Promise<MappingRow[]> {
    const { data, error } = await this.db
      .from('accounting_mappings')
      .select('kind, local_key, external_id, external_name')
      .eq('connection_id', connectionId);
    dbError('load mappings', error);
    return (data ?? []) as MappingRow[];
  }

  async loadReceipt(receiptId: string, userId: string): Promise<ReceiptRow | null> {
    const { data, error } = await this.db
      .from('money_receipts')
      .select('id, image_paths, extraction')
      .eq('id', receiptId)
      .eq('user_id', userId)
      .is('deleted_at', null)
      .maybeSingle();
    dbError('load receipt', error);
    return (data as ReceiptRow | null) ?? null;
  }

  async downloadReceiptPage(path: string, fileName: string): Promise<ReceiptFile> {
    const { data, error } = await this.db.storage.from(RECEIPTS_BUCKET).download(path);
    if (error || !data) {
      throw new AccountingError(
        'transient',
        `download ${path}: ${error?.message ?? 'no data'}`,
      );
    }
    return {
      fileName,
      contentType: contentTypeFor(path, data.type),
      bytes: new Uint8Array(await data.arrayBuffer()),
    };
  }

  async getLink(transactionId: string, connectionId: string): Promise<LinkRow | null> {
    const { data, error } = await this.db
      .from('accounting_links')
      .select(
        'transaction_id, connection_id, user_id, external_id, external_type, attachment_external_id, synced_at',
      )
      .eq('transaction_id', transactionId)
      .eq('connection_id', connectionId)
      .maybeSingle();
    dbError('load link', error);
    return (data as LinkRow | null) ?? null;
  }

  async saveLink(link: LinkRow): Promise<void> {
    const { error } = await this.db
      .from('accounting_links')
      .upsert(link, { onConflict: 'transaction_id,connection_id' });
    dbError('save link', error);
  }

  async deleteLink(transactionId: string, connectionId: string): Promise<void> {
    const { error } = await this.db
      .from('accounting_links')
      .delete()
      .eq('transaction_id', transactionId)
      .eq('connection_id', connectionId);
    dbError('delete link', error);
  }

  async updateJob(jobId: string, patch: JobPatch): Promise<void> {
    const { error } = await this.db.from('accounting_sync_jobs').update(patch).eq('id', jobId);
    dbError('update job', error);
  }
}
