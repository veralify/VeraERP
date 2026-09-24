// accounting-disconnect: ends an integration.
//
//   POST /functions/v1/accounting-disconnect
//   Authorization: Bearer <user access token>
//   { "connection_id": "uuid" }
//   → { "ok": true, "revoked": true | false }
//
// Revokes the grant at the provider where it has an endpoint for that (or,
// when other connections share the grant, detaches just this company), then
// deletes the Vault secret and marks the connection `revoked`. Mappings and
// links are kept, so reconnecting the same company picks up where it left
// off. Queued jobs are closed as `dead` — nothing will send them now.

import { corsHeaders } from '../_shared/http.ts';
import { createAdapter } from '../_shared/accounting/adapters.ts';
import {
  readConnectionToken,
  releaseConnectionToken,
  SupabaseSyncStore,
} from '../_shared/accounting/store.ts';
import {
  errorResponse,
  HttpError,
  isUuid,
  jsonResponse,
  readJson,
  requireUser,
  serviceClient,
} from '../_shared/accounting/supabase.ts';
import { TokenManager } from '../_shared/accounting/sync.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'METHOD_NOT_ALLOWED', message: 'Use POST.' }, 405);
  }
  try {
    const db = serviceClient();
    const user = await requireUser(req, db);
    const body = await readJson(req);
    if (!isUuid(body.connection_id)) {
      throw new HttpError(400, 'INVALID_CONNECTION', 'connection_id is required.');
    }
    const store = new SupabaseSyncStore(db);
    const connection = await store.loadConnection(body.connection_id);
    if (!connection || connection.user_id !== user.id) {
      throw new HttpError(404, 'CONNECTION_NOT_FOUND', 'Connection not found.');
    }

    let revoked = false;
    const stored = await readConnectionToken(db, connection.id);
    if (stored) {
      try {
        const adapter = createAdapter(connection.provider);
        const tokens = new TokenManager(store, adapter, connection);
        // Refresh first if needed: detaching one tenant needs a live access token.
        const ctx = await tokens.context();
        await adapter.revoke(ctx, { tokenShared: stored.sharedWith > 0 });
        revoked = true;
      } catch (error) {
        // Best effort: an already-dead grant must not block the disconnect.
        console.warn('accounting-disconnect: provider revoke failed', connection.provider, error);
      }
    }

    await releaseConnectionToken(db, connection.id);
    const { error: jobsError } = await db
      .from('accounting_sync_jobs')
      .update({ status: 'dead', last_error: 'Integration disconnected', locked_at: null })
      .eq('connection_id', connection.id)
      .in('status', ['pending', 'failed']);
    if (jobsError) console.warn('accounting-disconnect: closing jobs failed', jobsError.message);

    return jsonResponse({ ok: true, revoked });
  } catch (error) {
    return errorResponse(error);
  }
});
