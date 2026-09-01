// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { decodeJwtPayload, millisToIso, transactionStatus, verifyAppleJws } from '../_shared/apple.ts';

const admin = () => createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });

async function planIdForAppleProduct(supabase: any, productId: string) {
  const { data, error } = await supabase.from('billing_products').select('plan_id').eq('provider', 'apple').eq('provider_product_id', productId).eq('is_active', true).maybeSingle();
  if (error || !data) throw error ?? new Error(`No Apple billing product mapping for ${productId}`);
  return data.plan_id;
}

async function resolveUser(supabase: any, token: unknown, originalTransactionId: string) {
  if (typeof token === 'string') {
    const { data } = await supabase.from('profiles').select('id').eq('id', token).maybeSingle();
    if (data?.id) return data.id;
  }
  const { data } = await supabase.from('iap_transactions').select('user_id').eq('apple_original_transaction_id', originalTransactionId).maybeSingle();
  if (data?.user_id) return data.user_id;
  await supabase.from('audit_logs').insert({ action: 'apple_iap_quarantine_unknown_app_account_token', target_type: 'apple_original_transaction', metadata: { appAccountToken: token, originalTransactionId } });
  throw new Error('Unknown appAccountToken; Apple notification quarantined');
}

async function upsertAppleTransaction(supabase: any, tx: any, notificationType?: string, subtype?: string) {
  const original = String(tx.originalTransactionId || tx.transactionId || '');
  const transactionId = String(tx.transactionId || original);
  const user_id = await resolveUser(supabase, tx.appAccountToken, original);
  const plan_id = await planIdForAppleProduct(supabase, String(tx.productId));
  const row = {
    user_id,
    apple_original_transaction_id: original,
    apple_transaction_id: transactionId,
    product_id: String(tx.productId),
    plan_id,
    status: transactionStatus(tx, notificationType, subtype),
    purchased_at: millisToIso(tx.purchaseDate) ?? new Date().toISOString(),
    expires_at: millisToIso(tx.expiresDate),
    environment: String(tx.environment || 'Production').toLowerCase() === 'sandbox' ? 'sandbox' : 'production',
    raw_payload: tx,
  };
  const { error } = await supabase.from('iap_transactions').upsert(row, { onConflict: 'apple_transaction_id' });
  if (error) throw error;
  const { error: rpcError } = await supabase.rpc('project_user_entitlements', { p_user_id: user_id });
  if (rpcError) throw rpcError;
  return user_id;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const { signedPayload } = await req.json();
  if (typeof signedPayload !== 'string') return json({ error: 'signedPayload is required.' }, 400);
  const payload = await verifyAppleJws(signedPayload, requireEnv('APPLE_ROOT_CA_PEM'));
  const notificationUUID = String(payload.notificationUUID || '');
  if (!notificationUUID) return json({ error: 'notificationUUID is required.' }, 400);
  const supabase = admin();
  const key = `apple:${notificationUUID}`;
  const { error: idemError } = await supabase.from('idempotency_keys').insert({ key, scope: 'webhook', request_hash: notificationUUID, status: 'pending', expires_at: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30).toISOString() });
  if (idemError?.code === '23505') return json({ ok: true, duplicate: true });
  if (idemError) throw idemError;
  const signedTransactionInfo = payload.data?.signedTransactionInfo;
  const tx = typeof signedTransactionInfo === 'string' ? await verifyAppleJws(signedTransactionInfo, requireEnv('APPLE_ROOT_CA_PEM')) : {};
  const userId = await upsertAppleTransaction(supabase, tx, String(payload.notificationType || ''), payload.subtype ? String(payload.subtype) : undefined);
  await supabase.from('idempotency_keys').update({ status: 'completed', response: { user_id: userId, notificationType: payload.notificationType } }).eq('key', key);
  return json({ ok: true, user_id: userId });
});
