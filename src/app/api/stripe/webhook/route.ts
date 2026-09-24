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
        } else if (session.mode === 'payment' && session.metadata?.type === 'session_booking') {
          await finalizeSessionBooking(stripe, session);
        }
        break;
      }
      case 'checkout.session.expired': {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode === 'payment' && session.metadata?.type === 'session_booking') {
          await releaseExpiredBooking(session);
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
      case 'account.updated': {
        const account = event.data.object as Stripe.Account;
        await supabaseAdmin
          .from('coach_stripe_accounts')
          .update({
            onboarding_status: account.details_submitted ? 'complete' : 'pending',
            charges_enabled: Boolean(account.charges_enabled),
            payouts_enabled: Boolean(account.payouts_enabled),
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_account_id', account.id);
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

/**
 * Confirms a paid coach session booking: marks the booking/session confirmed
 * and records the payment split (coach transfer vs. platform fee) so the
 * coach portal and payout ledger reflect the completed Connect payment.
 */
async function finalizeSessionBooking(
  stripe: ReturnType<typeof getStripe>,
  session: Stripe.Checkout.Session,
) {
  const bookingId = session.metadata?.booking_id;
  const sessionId = session.metadata?.session_id;
  const coachId = session.metadata?.coach_id;
  const clientId = session.metadata?.client_id;
  const paymentIntentId =
    typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id;
  if (!bookingId || !sessionId || !coachId || !clientId || !paymentIntentId) return;

  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
  const amountCents = paymentIntent.amount;
  const platformFeeCents = paymentIntent.application_fee_amount ?? 0;
  const currency = paymentIntent.currency.toUpperCase();

  const updates = await Promise.all([
    supabaseAdmin.from('session_bookings').update({ status: 'confirmed' }).eq('id', bookingId),
    supabaseAdmin.from('coach_sessions').update({ status: 'confirmed' }).eq('id', sessionId),
  ]);
  // Throwing turns into a 500, so Stripe retries instead of the payment silently
  // leaving the booking unconfirmed.
  for (const { error } of updates) if (error) throw new Error(error.message);

  const { data: paymentRow, error: paymentError } = await supabaseAdmin
    .from('session_payment_intents')
    .upsert(
      {
        session_id: sessionId,
        client_id: clientId,
        coach_id: coachId,
        stripe_payment_intent_id: paymentIntentId,
        amount_cents: amountCents,
        currency,
        platform_fee_cents: platformFeeCents,
        status: 'succeeded',
      },
      { onConflict: 'session_id' },
    )
    .select('id')
    .single();

  if (paymentError) throw new Error(paymentError.message);

  if (paymentRow) {
    // Stripe delivers webhooks at least once; skip the ledger insert on a redelivery
    // so the coach isn't credited twice for one payment.
    const { data: existingCharge } = await supabaseAdmin
      .from('coach_transactions')
      .select('id')
      .eq('session_payment_intent_id', paymentRow.id)
      .eq('type', 'charge')
      .limit(1)
      .maybeSingle();
    if (existingCharge) return;

    const { error: ledgerError } = await supabaseAdmin.from('coach_transactions').insert({
      coach_id: coachId,
      session_payment_intent_id: paymentRow.id,
      type: 'charge',
      amount_cents: amountCents - platformFeeCents,
      currency,
      stripe_ref: paymentIntentId,
    });
    if (ledgerError) throw new Error(ledgerError.message);
  }
}

/**
 * The booking route reserves the slot before sending the client to Checkout. If
 * they never pay, Checkout expires the session; without this the slot stayed
 * "booked" forever and nobody else could book it.
 */
async function releaseExpiredBooking(session: Stripe.Checkout.Session) {
  const bookingId = session.metadata?.booking_id;
  const sessionId = session.metadata?.session_id;
  const clientId = session.metadata?.client_id;
  if (!bookingId || !sessionId || !clientId) return;

  const { data: released, error } = await supabaseAdmin
    .from('session_bookings')
    .delete()
    .eq('id', bookingId)
    .eq('status', 'payment_required')
    .select('id');
  if (error) throw new Error(error.message);
  if (!released?.length) return; // Already paid or cleaned up.

  const { error: slotError } = await supabaseAdmin
    .from('coach_sessions')
    .update({ status: 'available', client_id: null })
    .eq('id', sessionId)
    .eq('status', 'booked')
    .eq('client_id', clientId);
  if (slotError) throw new Error(slotError.message);
}
