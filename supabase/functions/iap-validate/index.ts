// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { assertAppAccountTokenMatches, millisToIso, transactionStatus, verifyAppleJws } from '../_shared/apple.ts';

const serviceClient = () => createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });
const userClient = (auth: string) => createClient(requireEnv('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY') || requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { global: { headers: { Authorization: auth } }, auth: { persistSession: false, autoRefreshToken: false } });

async function planIdForAppleProduct(supabase: any, productId: string) {
  const { data, error } = await supabase.from('billing_products').select('plan_id').eq('provider', 'apple').eq('provider_product_id', productId).eq('is_active', true).maybeSingle();
  if (error || !data) throw error ?? new Error(`No Apple billing product mapping for ${productId}`);
  return data.plan_id;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'Authentication required.' }, 401);
  const { data: authData, error: authError } = await userClient(auth).auth.getUser();
  if (authError || !authData.user) return json({ error: 'Invalid session.' }, 401);
  const { signedTransaction } = await req.json();
  if (typeof signedTransaction !== 'string') return json({ error: 'signedTransaction is required.' }, 400);
  const tx = await verifyAppleJws(signedTransaction, requireEnv('APPLE_ROOT_CA_PEM'));
  try {
    assertAppAccountTokenMatches(tx.appAccountToken, authData.user.id);
  } catch (error) {
    return json({ error: error.message }, 403);
  }
  const supabase = serviceClient();
  const plan_id = await planIdForAppleProduct(supabase, String(tx.productId));
  const row = {
    user_id: authData.user.id,
    apple_original_transaction_id: String(tx.originalTransactionId || tx.transactionId),
    apple_transaction_id: String(tx.transactionId),
    product_id: String(tx.productId),
    plan_id,
    status: transactionStatus(tx),
    purchased_at: millisToIso(tx.purchaseDate) ?? new Date().toISOString(),
    expires_at: millisToIso(tx.expiresDate),
    environment: String(tx.environment || 'Production').toLowerCase() === 'sandbox' ? 'sandbox' : 'production',
    raw_payload: tx,
  };
  const { error } = await supabase.from('iap_transactions').upsert(row, { onConflict: 'apple_transaction_id' });
  if (error) throw error;
  const { data: entitlements, error: rpcError } = await supabase.rpc('project_user_entitlements', { p_user_id: authData.user.id });
  if (rpcError) throw rpcError;
  return json({ ok: true, entitlements });
});
