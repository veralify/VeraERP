// Deletes the caller's Veralify account: an App Store requirement for any app
// that lets people create one (guideline 5.1.1(v)).
//
// The client cannot delete an auth user, so this runs with the service role,
// and only for the user whose token it was called with. In order:
//
//   1. Vault secrets holding the user's accounting tokens. They are referenced
//      by id only, so no cascade would remove them.
//   2. The user's folder in the private `receipts` bucket. Storage objects do
//      not cascade from the database either.
//   3. The auth user. Its profile, and every money_* and accounting_* row
//      through the profile, go by cascade.
//
// Each step can be repeated safely, and the user goes last: if anything
// before it fails, the account still exists and the app can simply try again.
// The other way round, a failure after deleting the user would leave files
// and tokens that nobody could ever ask to delete.
//
// Everything is plain REST against the project's own endpoints, so the
// network is a single injectable `fetch` and the whole flow is testable
// without a server.

import { corsHeaders, json } from '../_shared/http.ts';

export interface AccountDeleteConfig {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  fetch: typeof fetch;
}

export const RECEIPTS_BUCKET = 'receipts';
const LIST_PAGE = 1000;
const REMOVE_BATCH = 500;

class StepError extends Error {
  constructor(step: string, status: number, detail: string) {
    super(`${step} failed (${status}): ${detail}`);
  }
}

function failure(status: number, error: string, message: string): Response {
  return json({ error, message }, status);
}

/** The bearer token, or null when the header is missing or malformed. */
export function bearerToken(header: string | null): string | null {
  const match = /^Bearer\s+(\S+)\s*$/i.exec(header ?? '');
  return match ? match[1] : null;
}

/**
 * Deletion is irreversible, so the body has to say so: `{"confirm": true}`.
 * Keeps a stray or replayed POST with a valid token from deleting an account.
 */
export async function isConfirmed(req: Request): Promise<boolean> {
  try {
    const body = await req.json();
    return typeof body === 'object' && body !== null && body.confirm === true;
  } catch {
    return false;
  }
}

function serviceHeaders(config: AccountDeleteConfig): HeadersInit {
  return {
    apikey: config.serviceRoleKey,
    Authorization: `Bearer ${config.serviceRoleKey}`,
    'Content-Type': 'application/json',
  };
}

/**
 * The user the token belongs to, as the auth server sees it — a signature
 * check alone would accept a token for a user already deleted or banned.
 * Null for anything that is not a live user session, including the service
 * role key itself, which has no user.
 */
export async function verifiedUserId(config: AccountDeleteConfig, token: string): Promise<string | null> {
  const response = await config.fetch(`${config.supabaseUrl}/auth/v1/user`, {
    headers: { apikey: config.anonKey, Authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null);
  return typeof user?.id === 'string' && user.id.length > 0 ? user.id : null;
}

async function deleteVaultSecrets(config: AccountDeleteConfig, userId: string): Promise<void> {
  const response = await config.fetch(`${config.supabaseUrl}/rest/v1/rpc/account_delete_vault_secrets`, {
    method: 'POST',
    headers: serviceHeaders(config),
    body: JSON.stringify({ p_user_id: userId }),
  });
  if (!response.ok) throw new StepError('vault secrets', response.status, await response.text());
}

interface StorageEntry {
  name: string;
  // Null for a folder: storage lists "directories" as entries without an id.
  id: string | null;
}

/**
 * Every object path under `prefix`, walking folders (`{user}/{receipt}/{page}.jpg`).
 *
 * VERIFY: Storage REST shapes as used by supabase-js — POST object/list/{bucket}
 * with {prefix, limit, offset, sortBy} returning folders as entries with a null
 * id, and DELETE object/{bucket} with {prefixes}.
 */
export async function listObjects(config: AccountDeleteConfig, prefix: string): Promise<string[]> {
  const paths: string[] = [];
  for (let offset = 0;; offset += LIST_PAGE) {
    const response = await config.fetch(
      `${config.supabaseUrl}/storage/v1/object/list/${RECEIPTS_BUCKET}`,
      {
        method: 'POST',
        headers: serviceHeaders(config),
        body: JSON.stringify({
          prefix,
          limit: LIST_PAGE,
          offset,
          sortBy: { column: 'name', order: 'asc' },
        }),
      },
    );
    if (!response.ok) throw new StepError('list receipts', response.status, await response.text());
    const entries = (await response.json()) as StorageEntry[];
    for (const entry of entries) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id === null) {
        paths.push(...await listObjects(config, path));
      } else {
        paths.push(path);
      }
    }
    if (entries.length < LIST_PAGE) break;
  }
  return paths;
}

async function removeReceipts(config: AccountDeleteConfig, userId: string): Promise<number> {
  const paths = await listObjects(config, userId);
  for (let start = 0; start < paths.length; start += REMOVE_BATCH) {
    const response = await config.fetch(`${config.supabaseUrl}/storage/v1/object/${RECEIPTS_BUCKET}`, {
      method: 'DELETE',
      headers: serviceHeaders(config),
      body: JSON.stringify({ prefixes: paths.slice(start, start + REMOVE_BATCH) }),
    });
    if (!response.ok) throw new StepError('remove receipts', response.status, await response.text());
  }
  return paths.length;
}

async function deleteAuthUser(config: AccountDeleteConfig, userId: string): Promise<void> {
  const response = await config.fetch(`${config.supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: 'DELETE',
    headers: serviceHeaders(config),
    // A hard delete: a soft-deleted auth user keeps its profile, and with it
    // every row this function exists to remove.
    // VERIFY: GoTrue admin DELETE /admin/users/{id} accepts should_soft_delete.
    body: JSON.stringify({ should_soft_delete: false }),
  });
  // Already gone (a retry after a lost response) is the outcome wanted.
  if (!response.ok && response.status !== 404) {
    throw new StepError('delete user', response.status, await response.text());
  }
}

export function configFromEnv(fetcher: typeof fetch = fetch): AccountDeleteConfig {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set');
  }
  return {
    supabaseUrl: supabaseUrl.replace(/\/+$/, ''),
    anonKey: Deno.env.get('SUPABASE_ANON_KEY') || serviceRoleKey,
    serviceRoleKey,
    fetch: fetcher,
  };
}

export function createHandler(getConfig: () => AccountDeleteConfig) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return failure(405, 'METHOD_NOT_ALLOWED', 'Use POST.');

    const token = bearerToken(req.headers.get('authorization'));
    if (!token) return failure(401, 'UNAUTHENTICATED', 'Sign in again, then delete the account.');
    if (!(await isConfirmed(req))) {
      return failure(400, 'CONFIRMATION_REQUIRED', 'Send {"confirm": true} to delete the account.');
    }

    let config: AccountDeleteConfig;
    try {
      config = getConfig();
    } catch (error) {
      console.error('account-delete: not configured', error);
      return failure(500, 'NOT_CONFIGURED', 'Account deletion is not available right now.');
    }

    let userId: string | null;
    try {
      userId = await verifiedUserId(config, token);
    } catch (error) {
      console.error('account-delete: could not verify the session', error);
      return failure(503, 'AUTH_UNAVAILABLE', 'Could not check your sign-in. Try again in a moment.');
    }
    if (!userId) return failure(401, 'UNAUTHENTICATED', 'Sign in again, then delete the account.');

    try {
      await deleteVaultSecrets(config, userId);
      const removed = await removeReceipts(config, userId);
      await deleteAuthUser(config, userId);
      console.log(`account-delete: deleted ${userId} (${removed} receipt files)`);
      return json({ ok: true });
    } catch (error) {
      console.error(`account-delete: ${userId}`, error);
      return failure(500, 'DELETE_FAILED', 'Your account could not be deleted. Nothing was lost; try again later.');
    }
  };
}
