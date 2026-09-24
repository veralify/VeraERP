// accounting-sync: the worker that pushes queued expense changes to the
// connected accounting providers.
//
//   POST /functions/v1/accounting-sync
//   Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
//   { "limit": 20 }
//
// Schedule it every minute with pg_cron + pg_net, as for notification-worker
// (see 20260925130000_accounting_sync.sql). Never hard-code the key in SQL;
// read it from Vault in the cron command.
//
// Jobs are claimed by claim_accounting_sync_jobs (FOR UPDATE SKIP LOCKED, and
// never two workers on one token bundle), then processed per connection by
// processConnectionJobs in _shared/accounting/sync.ts.

import { corsHeaders } from '../_shared/http.ts';
import { createAdapter } from '../_shared/accounting/adapters.ts';
import { SupabaseSyncStore } from '../_shared/accounting/store.ts';
import {
  errorResponse,
  isServiceRequest,
  jsonResponse,
  readJson,
  serviceClient,
} from '../_shared/accounting/supabase.ts';
import {
  failurePatch,
  groupByConnection,
  type JobOutcome,
  processConnectionJobs,
  type SyncJob,
  toAccountingError,
} from '../_shared/accounting/sync.ts';
import { AccountingError } from '../_shared/accounting/types.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'METHOD_NOT_ALLOWED', message: 'Use POST.' }, 405);
  }
  if (!isServiceRequest(req)) {
    return jsonResponse({ error: 'UNAUTHENTICATED', message: 'Service role only.' }, 401);
  }
  try {
    const body = await readJson(req);
    // Jobs run one after another; 20 keeps a run well inside the function's
    // wall-clock limit even when every job uploads a receipt.
    const limit = Math.max(1, Math.min(Number(body.limit ?? 20) || 20, 100));
    const db = serviceClient();
    const { data, error } = await db.rpc('claim_accounting_sync_jobs', { p_limit: limit });
    if (error) throw new Error(`claim_accounting_sync_jobs: ${error.message}`);
    const jobs = (data ?? []) as SyncJob[];
    const store = new SupabaseSyncStore(db);

    // One connection at a time. Two connections can share a token bundle (one
    // Xero consent, several organisations) and a refresh rotates it, so
    // running them side by side could spend the same refresh token twice.
    const results: JobOutcome[] = [];
    for (const [connectionId, group] of groupByConnection(jobs)) {
      try {
        const connection = await store.loadConnection(connectionId);
        // Jobs cascade with their connection, so this is a race with a delete.
        if (!connection) throw new AccountingError('permanent', 'Connection no longer exists');
        const adapter = createAdapter(connection.provider);
        results.push(...await processConnectionJobs({ store, adapter }, connectionId, group));
      } catch (caught) {
        // Setup failed (e.g. a missing client secret): every job in the group
        // takes one attempt on the normal schedule.
        const failure = toAccountingError(caught);
        for (const job of group) {
          const patch = failurePatch(job, failure);
          await store.updateJob(job.id, patch);
          results.push({
            id: job.id,
            status: patch.status as 'failed' | 'dead',
            error: failure.message,
          });
        }
      }
    }
    return jsonResponse({ ok: true, claimed: jobs.length, results });
  } catch (error) {
    return errorResponse(error);
  }
});
