import { getPlanByPriceId } from '@config/billing';
import { apiLogger } from '@lib/logger';
import { getStripe } from '@lib/stripe/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { NextResponse } from 'next/server';
import type Stripe from 'stripe';

// Stripe sends the raw request body for signature verification, so this
// route must read the untouched text body rather than parsed JSON.
export async function POST(request: Request) {
  const log = apiLogger('/api/stripe/webhook', request);

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  const signature = request.headers.get('stripe-signature');

  if (!webhookSecret || !signature) {
    log.error('missing webhook secret or signature header');
    log.done(400);
    return NextResponse.json({ error: 'Webhook not configured.' }, { status: 400 });
  }

  let stripe: ReturnType<typeof getStripe>;
  try {
    stripe = getStripe();
  } catch (err) {
    log.error('stripe not configured', err instanceof Error ? err.message : String(err));
    log.done(500);
    return NextResponse.json({ error: 'Stripe not configured.' }, { status: 500 });
  }

  const rawBody = await request.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (err) {
    log.warn('signature verification failed', err instanceof Error ? err.message : String(err));
    log.done(400);
    return NextResponse.json({ error: 'Invalid signature.' }, { status: 400 });
  }

  log.info('event received', event.type);

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode === 'subscription' && session.subscription) {
          await syncSubscriptionForCustomer(
            stripe,
            typeof session.customer === 'string' ? session.customer : session.customer?.id,
            typeof session.subscription === 'string'
              ? session.subscription
              : session.subscription.id,
            session.client_reference_id ?? session.metadata?.user_id ?? null,
          );
        }
        break;
      }
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        await syncSubscriptionForCustomer(
          stripe,
          typeof subscription.customer === 'string'
            ? subscription.customer
            : subscription.customer.id,
          subscription.id,
          subscription.metadata?.user_id ?? null,
          subscription,
        );
        break;
      }
      default:
        // No-op for events we don't act on.
        break;
    }
  } catch (err) {
    log.error('event handling failed', err instanceof Error ? err.message : String(err));
    log.done(500);
    return NextResponse.json({ error: 'Webhook handler error.' }, { status: 500 });
  }

  log.done(200);
  return NextResponse.json({ received: true });
}

/**
 * Fetches the latest subscription state from Stripe (or uses the one already
 * provided by the event) and reconciles `public.profiles` for the associated
 * user: subscription tier, status, Stripe customer/subscription ids, and the
 * monthly AI credit allowance for the resolved plan.
 */
async function syncSubscriptionForCustomer(
  stripe: ReturnType<typeof getStripe>,
  customerId: string | undefined,
  subscriptionId: string,
  userIdHint: string | null,
  subscriptionOverride?: Stripe.Subscription,
) {
  if (!customerId) return;

  const subscription =
    subscriptionOverride ?? (await stripe.subscriptions.retrieve(subscriptionId));

  const priceId = subscription.items.data[0]?.price?.id;
  const isActive = subscription.status === 'active' || subscription.status === 'trialing';
  const plan = priceId ? getPlanByPriceId(priceId) : undefined;

  const tier = isActive && plan ? plan.tier : 'free';
  const monthlyAiCredits = isActive && plan ? plan.monthlyAiCredits : 50;

  // Resolve which profile row to update: prefer the user id carried on the
  // subscription/session metadata, falling back to a lookup by customer id
  // for events that don't include it (e.g. a portal-initiated cancellation).
  let userId = userIdHint ?? subscription.metadata?.user_id ?? null;
  if (!userId) {
    const { data: existing } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('stripe_customer_id', customerId)
      .maybeSingle();
    userId = existing?.id ?? null;
  }

  if (!userId) return;

  await supabaseAdmin
    .from('profiles')
    .update({
      stripe_customer_id: customerId,
      stripe_subscription_id: subscription.id,
      subscription_status: subscription.status,
      subscription_tier: tier,
      monthly_ai_credits: monthlyAiCredits,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId);
}
