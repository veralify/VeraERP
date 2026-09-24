// fx-rates-sync — loads the ECB euro reference rates into public.fx_rates.
//
// Run daily by pg_cron (see migration 20260925140000_money_fx_conversion.sql
// for the schedule). Each run upserts today's publication; the first run on
// an empty table, or a POST with {"backfill": true}, loads the 90-day history
// instead. After the upsert it fills home_amount on transactions that were
// saved before their rate existed.
//
// Idempotent: rates are keyed on (rate_date, base, quote), so running twice,
// or on a day the ECB did not publish, rewrites the same rows.
//
// Auth: Authorization: Bearer <service role key>. Nothing else may run it.
// deno-lint-ignore no-import-prefix -- pinned inline like the other functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { isServiceRoleRequest } from './auth.ts';
import { EcbParseError, type FxRateRow } from './ecb.ts';
import { type RatesStore, syncRates, UpstreamError } from './sync.ts';

function supabaseStore(): RatesStore {
  const admin = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return {
    async hasAnyRates() {
      const { count, error } = await admin.from('fx_rates').select('rate_date', {
        count: 'exact',
        head: true,
      });
      if (error) throw new Error(`fx_rates count failed: ${error.message}`);
      return (count ?? 0) > 0;
    },
    async upsertRates(rows: FxRateRow[]) {
      const { error } = await admin.from('fx_rates').upsert(rows, {
        onConflict: 'rate_date,base,quote',
      });
      if (error) throw new Error(`fx_rates upsert failed: ${error.message}`);
    },
    async backfillHomeAmounts() {
      const { data, error } = await admin.rpc('money_backfill_home_amounts');
      if (error) throw new Error(`home_amount backfill failed: ${error.message}`);
      return typeof data === 'number' ? data : 0;
    },
  };
}

async function wantsBackfill(req: Request): Promise<boolean> {
  if (new URL(req.url).searchParams.get('backfill') === '1') return true;
  if (req.method !== 'POST') return false;
  try {
    const body = await req.json();
    return body?.backfill === true;
  } catch {
    // An empty body (the cron job sends {}) or none at all means a daily run.
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST' && req.method !== 'GET') {
    return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  }
  if (!isServiceRoleRequest(req, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')) {
    return json({ error: 'UNAUTHENTICATED', message: 'Service role key required.' }, 401);
  }

  try {
    const result = await syncRates({ store: supabaseStore(), backfill: await wantsBackfill(req) });
    console.log(JSON.stringify({ event: 'fx_rates_synced', ...result }));
    return json({ ok: true, ...result });
  } catch (error) {
    const message = (error as Error).message;
    console.error(JSON.stringify({ event: 'fx_rates_sync_failed', message }));
    // 502 when the ECB side failed (worth retrying later), 500 for our own.
    const upstream = error instanceof UpstreamError || error instanceof EcbParseError;
    return json(
      { error: upstream ? 'UPSTREAM_FAILED' : 'SYNC_FAILED', message },
      upstream ? 502 : 500,
    );
  }
});
