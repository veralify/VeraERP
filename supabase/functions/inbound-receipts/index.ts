// inbound-receipts — receipts forwarded by e-mail to receipts+{token}@INBOUND_EMAIL_DOMAIN.
//
// A provider-agnostic webhook: the e-mail provider (through a small relay,
// see payload.ts) POSTs a normalised JSON e-mail signed with
// INBOUND_WEBHOOK_SECRET. For each usable attachment this stores the file in
// the private receipts bucket as {user_id}/{receipt_id}/1.{jpg|png|pdf},
// creates a money_receipts row with source 'email', and then asks ai-gateway's
// receipts-extract to read it for that user. The user reviews and confirms
// the result in the app, exactly as for a photographed receipt.
//
// Deploy with `supabase functions deploy inbound-receipts --no-verify-jwt`:
// the caller is a mail provider with no Supabase token, and the HMAC
// signature is the authentication.
//
// Secrets: INBOUND_WEBHOOK_SECRET, INBOUND_EMAIL_DOMAIN (plus the platform's
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY).
// deno-lint-ignore no-import-prefix -- pinned inline like the other functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { requireEnv } from '../_shared/http.ts';
import { handleInbound, type InboundStore } from './handler.ts';

const supabaseUrl = requireEnv('SUPABASE_URL');
const serviceRoleKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const store: InboundStore = {
  async findAddress(token) {
    const { data, error } = await admin
      .from('money_inbound_addresses')
      .select('user_id, enabled')
      .eq('token', token)
      .maybeSingle();
    if (error) throw new Error(`inbound address lookup failed: ${error.message}`);
    return data ? { userId: data.user_id as string, enabled: data.enabled as boolean } : null;
  },
  async homeCurrency(userId) {
    const { data, error } = await admin.rpc('money_home_currency', { p_user_id: userId });
    if (error) throw new Error(`home currency lookup failed: ${error.message}`);
    return typeof data === 'string' ? data : 'EUR';
  },
  async receiptExists(receiptId) {
    const { data, error } = await admin
      .from('money_receipts')
      .select('id')
      .eq('id', receiptId)
      .maybeSingle();
    if (error) throw new Error(`receipt lookup failed: ${error.message}`);
    return data !== null;
  },
  async uploadReceiptFile(path, bytes, contentType) {
    const { error } = await admin.storage.from('receipts').upload(path, bytes, {
      contentType,
      upsert: true,
    });
    if (error) throw new Error(`receipt upload failed: ${error.message}`);
  },
  async insertReceipt(row) {
    const { error } = await admin.from('money_receipts').insert(row);
    if (error?.code === '23505') return 'duplicate';
    if (error) throw new Error(`receipt insert failed: ${error.message}`);
    return 'inserted';
  },
};

// Supabase's edge runtime keeps the isolate alive for promises handed to
// waitUntil; elsewhere (local serve) the work simply runs unawaited.
const runtime = (globalThis as { EdgeRuntime?: { waitUntil(p: Promise<unknown>): void } })
  .EdgeRuntime;

Deno.serve(async (req) => {
  try {
    return await handleInbound(req, {
      secret: Deno.env.get('INBOUND_WEBHOOK_SECRET') ?? '',
      domain: Deno.env.get('INBOUND_EMAIL_DOMAIN') ?? '',
      supabaseUrl,
      serviceRoleKey,
      store,
      background: (work) => {
        const guarded = work.catch((error) =>
          console.error(
            JSON.stringify({ event: 'inbound_receipts_extract_failed', message: String(error) }),
          )
        );
        if (runtime) runtime.waitUntil(guarded);
      },
    });
  } catch (error) {
    // Storage or database trouble: 500 so the provider retries. Receipt ids
    // come from the file, so the retry does not duplicate what already landed.
    console.error(JSON.stringify({ event: 'inbound_receipts_failed', message: String(error) }));
    return new Response(JSON.stringify({ error: 'INTERNAL' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
