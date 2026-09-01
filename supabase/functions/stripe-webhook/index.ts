// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';
import { corsHeaders, json, requireEnv } from '../_shared/http.ts';
import { mapStripeSubscriptionStatus, secondsToIso, verifyStripeSignature } from '../_shared/stripe.ts';

const admin = () => createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });

async function stripeGet(path: string) {
  const res = await fetch(`https://api.stripe.com/v1/${path}`, { headers: { Authorization: `Bearer ${requireEnv('STRIPE_SECRET_KEY')}` } });
  if (!res.ok) throw new Error(`Stripe API ${path} failed: ${res.status}`);
  return await res.json();
}

async function planIdForStripeProduct(supabase: any, productId: string) {
  const { data, error } = await supabase.from('billing_products').select('plan_id, provider_product_id').eq('provider', 'stripe').eq('is_active', true);
  if (error) throw error;
  const row = (data ?? []).find((r: any) => r.provider_product_id === productId || (r.provider_product_id?.startsWith('env:') && Deno.env.get(r.provider_product_id.slice(4)) === productId));
  if (!row) throw new Error(`No active Stripe billing product mapping for ${productId}`);
  return row.plan_id;
}

async function userIdForSubscription(supabase: any, subscription: any, fallback?: any) {
  const metadataUser = subscription?.metadata?.user_id || fallback?.metadata?.user_id || fallback?.client_reference_id;
  if (metadataUser) return metadataUser;
  const { data } = await supabase.from('subscriptions').select('user_id').or(`stripe_subscription_id.eq.${subscription.id},stripe_customer_id.eq.${subscription.customer}`).limit(1).maybeSingle();
  if (data?.user_id) return data.user_id;
  await supabase.from('audit_logs').insert({ action: 'stripe_subscription_quarantine', target_type: 'stripe_subscription', target_id: null, metadata: { subscription_id: subscription.id, customer: subscription.customer } });
  throw new Error('Unable to resolve Stripe subscription user_id');
}

async function upsertSubscription(supabase: any, subscription: any, fallback?: any) {
  const item = subscription.items?.data?.[0];
  const productId = typeof item?.price?.product === 'string' ? item.price.product : item?.price?.product?.id;
  if (!productId) throw new Error('Stripe subscription has no product id');
  const plan_id = await planIdForStripeProduct(supabase, productId);
  const user_id = await userIdForSubscription(supabase, subscription, fallback);
  const row = {
    user_id,
    stripe_customer_id: typeof subscription.customer === 'string' ? subscription.customer : subscription.customer?.id,
    stripe_subscription_id: subscription.id,
    plan_id,
    status: mapStripeSubscriptionStatus(subscription.status),
    current_period_start: secondsToIso(subscription.current_period_start),
    current_period_end: secondsToIso(subscription.current_period_end),
    cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
  };
  const { error } = await supabase.from('subscriptions').upsert(row, { onConflict: 'stripe_subscription_id' });
  if (error) throw error;
  const { error: rpcError } = await supabase.rpc('project_user_entitlements', { p_user_id: user_id });
  if (rpcError) throw rpcError;
  return user_id;
}

async function processEvent(supabase: any, event: any) {
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object;
      const subId = typeof session.subscription === 'string' ? session.subscription : session.subscription?.id;
      if (subId) return await upsertSubscription(supabase, await stripeGet(`subscriptions/${subId}?expand[]=items.data.price.product`), session);
      return null;
    }
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted':
      return await upsertSubscription(supabase, event.data.object);
    case 'invoice.paid':
    case 'invoice.payment_succeeded':
    case 'invoice.payment_failed': {
      const invoice = event.data.object;
      const subId = typeof invoice.subscription === 'string' ? invoice.subscription : invoice.subscription?.id;
      if (subId) return await upsertSubscription(supabase, await stripeGet(`subscriptions/${subId}?expand[]=items.data.price.product`));
      return null;
    }
    case 'entitlements.active_entitlement_summary.updated':
      return null;
    default:
      return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const body = await req.text();
  if (!(await verifyStripeSignature(body, req.headers.get('stripe-signature'), requireEnv('STRIPE_WEBHOOK_SECRET')))) return json({ error: 'Invalid Stripe signature.' }, 400);
  const event = JSON.parse(body);
  const supabase = admin();
  const eventKey = `stripe:${event.id}`;
  const { error: idemError } = await supabase.from('idempotency_keys').insert({ key: eventKey, scope: 'webhook', request_hash: event.id, status: 'pending', expires_at: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30).toISOString() });
  if (idemError?.code === '23505') return json({ ok: true, duplicate: true });
  if (idemError) throw idemError;
  await supabase.from('subscription_events').insert({ stripe_event_id: event.id, event_type: event.type, payload: event, processed: false });
  const userId = await processEvent(supabase, event);
  await supabase.from('subscription_events').update({ processed: true, processed_at: new Date().toISOString() }).eq('stripe_event_id', event.id);
  await supabase.from('idempotency_keys').update({ status: 'completed', response: { user_id: userId, type: event.type } }).eq('key', eventKey);
  return json({ ok: true, user_id: userId });
});
