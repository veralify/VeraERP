import { apiLogger } from '@lib/logger';
import { getPlatformFeePercentage } from '@lib/stripe/platformFee';
import { getStripe } from '@lib/stripe/server';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { NextResponse } from 'next/server';

function originFromRequest(request: Request) {
  const url = new URL(request.url);
  return `${url.protocol}//${url.host}`;
}

/**
 * Client books and pays for a coach session in one step: reserves the
 * session slot, creates a `session_bookings` row (server-side only —
 * clients hold no insert grant on that table per RLS), and starts a Stripe
 * Checkout Session that routes payment to the coach's connected account
 * minus the platform fee.
 */
export async function POST(request: Request) {
  const log = apiLogger('/api/stripe/bookings/checkout', request);
  const origin = originFromRequest(request);

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    log.done(401);
    return NextResponse.redirect(new URL('/?auth=required', request.url), { status: 303 });
  }

  const formData = await request.formData().catch(() => null);
  const sessionId = formData?.get('sessionId');
  if (typeof sessionId !== 'string' || !sessionId) {
    log.warn('rejected: missing sessionId');
    log.done(400);
    return NextResponse.json({ error: 'Missing session id.' }, { status: 400 });
  }

  const { data: session } = await supabaseAdmin
    .from('coach_sessions')
    .select('id, coach_id, duration_minutes, status, scheduled_at')
    .eq('id', sessionId)
    .maybeSingle();

  if (
    !session ||
    session.status !== 'available' ||
    new Date(session.scheduled_at).getTime() <= Date.now()
  ) {
    log.warn('rejected: session not available', sessionId);
    log.done(409);
    return NextResponse.redirect(new URL('/coaches?error=session-unavailable', request.url), {
      status: 303,
    });
  }
  if (session.coach_id === user.id) {
    log.warn('rejected: coach cannot book own session');
    log.done(400);
    return NextResponse.redirect(new URL('/coaches?error=own-session', request.url), {
      status: 303,
    });
  }

  const [{ data: coachProfile }, { data: stripeAccount }] = await Promise.all([
    supabaseAdmin
      .from('coach_profiles')
      .select('hourly_rate, currency')
      .eq('id', session.coach_id)
      .maybeSingle(),
    supabaseAdmin
      .from('coach_stripe_accounts')
      .select('stripe_account_id, charges_enabled')
      .eq('coach_id', session.coach_id)
      .maybeSingle(),
  ]);

  if (!coachProfile?.hourly_rate || !stripeAccount?.charges_enabled) {
    log.warn('rejected: coach not payable', session.coach_id);
    log.done(409);
    return NextResponse.redirect(new URL('/coaches?error=coach-not-payable', request.url), {
      status: 303,
    });
  }

  const amountCents = Math.round((coachProfile.hourly_rate * session.duration_minutes * 100) / 60);
  const feePercentage = await getPlatformFeePercentage(session.coach_id);
  const platformFeeCents = Math.round((amountCents * feePercentage) / 100);
  const currency = coachProfile.currency.toLowerCase();

  // Reserve the slot atomically: only succeeds if still 'available'.
  const { data: reserved, error: reserveError } = await supabaseAdmin
    .from('coach_sessions')
    .update({ status: 'booked', client_id: user.id })
    .eq('id', sessionId)
    .eq('status', 'available')
    .select('id')
    .maybeSingle();
  if (reserveError || !reserved) {
    log.warn('rejected: reservation race', sessionId);
    log.done(409);
    return NextResponse.redirect(new URL('/coaches?error=session-unavailable', request.url), {
      status: 303,
    });
  }

  const { data: booking, error: bookingError } = await supabaseAdmin
    .from('session_bookings')
    .insert({ session_id: sessionId, client_id: user.id, status: 'payment_required' })
    .select('id')
    .single();
  if (bookingError || !booking) {
    log.error('booking insert failed', bookingError?.message ?? 'unknown');
    await supabaseAdmin
      .from('coach_sessions')
      .update({ status: 'available', client_id: null })
      .eq('id', sessionId);
    log.done(500);
    return NextResponse.redirect(new URL('/coaches?error=booking-failed', request.url), {
      status: 303,
    });
  }

  let stripe: ReturnType<typeof getStripe>;
  try {
    stripe = getStripe();
  } catch (err) {
    log.error('stripe not configured', err instanceof Error ? err.message : String(err));
    await rollback(sessionId, booking.id);
    log.done(500);
    return NextResponse.json({ error: 'Stripe is not configured.' }, { status: 500 });
  }

  try {
    const checkoutSession = await stripe.checkout.sessions.create({
      mode: 'payment',
      customer_email: user.email ?? undefined,
      client_reference_id: user.id,
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency,
            unit_amount: amountCents,
            product_data: { name: 'Veralify coaching session' },
          },
        },
      ],
      payment_intent_data: {
        application_fee_amount: platformFeeCents,
        transfer_data: { destination: stripeAccount.stripe_account_id },
        metadata: {
          type: 'session_booking',
          booking_id: booking.id,
          session_id: sessionId,
          coach_id: session.coach_id,
          client_id: user.id,
        },
      },
      metadata: {
        type: 'session_booking',
        booking_id: booking.id,
        session_id: sessionId,
        coach_id: session.coach_id,
        client_id: user.id,
      },
      success_url: `${origin}/dashboard/billing?booking=success`,
      cancel_url: `${origin}/coaches?booking=cancelled`,
    });

    if (!checkoutSession.url) {
      log.error('checkout session missing url');
      await rollback(sessionId, booking.id);
      log.done(502);
      return NextResponse.json({ error: 'Could not start checkout.' }, { status: 502 });
    }

    log.done(303, { userId: user.id, sessionId });
    return NextResponse.redirect(checkoutSession.url, { status: 303 });
  } catch (err) {
    log.error(
      'stripe checkout session create failed',
      err instanceof Error ? err.message : String(err),
    );
    await rollback(sessionId, booking.id);
    log.done(502);
    return NextResponse.json({ error: 'Could not start checkout.' }, { status: 502 });
  }
}

async function rollback(sessionId: string, bookingId: string) {
  await supabaseAdmin.from('session_bookings').delete().eq('id', bookingId);
  await supabaseAdmin
    .from('coach_sessions')
    .update({ status: 'available', client_id: null })
    .eq('id', sessionId);
}
