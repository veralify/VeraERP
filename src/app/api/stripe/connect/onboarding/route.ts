import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { apiLogger } from '@lib/logger';
import { getStripe } from '@lib/stripe/server';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { NextResponse } from 'next/server';

function originFromRequest(request: Request) {
  const url = new URL(request.url);
  return `${url.protocol}//${url.host}`;
}

export async function POST(request: Request) {
  const log = apiLogger('/api/stripe/connect/onboarding', request);
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    log.done(401);
    return NextResponse.redirect(new URL('/?auth=required', request.url), { status: 303 });
  }

  const entitlements = await getUserEntitlements(user.id).catch(() => []);
  if (!hasEntitlement(entitlements, 'VERALIFY_COACH')) {
    log.warn('rejected: missing coach entitlement', user.id);
    log.done(403);
    return NextResponse.redirect(new URL('/dashboard/coach?error=coach-entitlement', request.url), {
      status: 303,
    });
  }

  const { data: coachProfile } = await supabase
    .from('coach_profiles')
    .select('id')
    .eq('id', user.id)
    .maybeSingle();
  if (!coachProfile) {
    log.warn('rejected: missing coach profile', user.id);
    log.done(400);
    return NextResponse.redirect(new URL('/dashboard/coach?error=coach-profile', request.url), {
      status: 303,
    });
  }

  let stripe: ReturnType<typeof getStripe>;
  try {
    stripe = getStripe();
  } catch (err) {
    log.error('stripe not configured', err instanceof Error ? err.message : String(err));
    log.done(500);
    return NextResponse.json({ error: 'Stripe is not configured.' }, { status: 500 });
  }

  const { data: existing } = await supabaseAdmin
    .from('coach_stripe_accounts')
    .select('stripe_account_id')
    .eq('coach_id', user.id)
    .maybeSingle();

  try {
    let accountId = existing?.stripe_account_id as string | undefined;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        country: process.env.STRIPE_CONNECT_COUNTRY ?? 'GB',
        email: user.email ?? undefined,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        metadata: { coach_id: user.id },
      });
      accountId = account.id;
      await supabaseAdmin.from('coach_stripe_accounts').upsert(
        {
          coach_id: user.id,
          stripe_account_id: accountId,
          onboarding_status: account.details_submitted ? 'complete' : 'pending',
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
        },
        { onConflict: 'coach_id' },
      );
    }

    const origin = originFromRequest(request);
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      refresh_url: `${origin}/dashboard/coach?connect=refresh`,
      return_url: `${origin}/dashboard/coach?connect=return`,
    });
    log.done(303, { coachId: user.id });
    return NextResponse.redirect(accountLink.url, { status: 303 });
  } catch (err) {
    log.error('connect onboarding failed', err instanceof Error ? err.message : String(err));
    log.done(502);
    return NextResponse.json(
      { error: 'Could not start Stripe Connect onboarding.' },
      { status: 502 },
    );
  }
}
