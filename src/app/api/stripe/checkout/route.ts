import { getPlanByTier, type SubscriptionTier } from '@config/billing';
import { getActiveBrand } from '@config/brands';
import { apiLogger } from '@lib/logger';
import { getStripe } from '@lib/stripe/server';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { NextResponse } from 'next/server';

/**
 * Starts a Stripe Checkout session (subscription mode) for the signed-in
 * user and redirects them to the hosted payment page. Called via a plain
 * `<form action="/api/stripe/checkout" method="POST">` from the pricing page
 * so it works without client-side JS.
 */
export async function POST(request: Request) {
  const log = apiLogger('/api/stripe/checkout', request);
  const brand = getActiveBrand();

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    log.warn('rejected: not authenticated');
    log.done(401);
    return NextResponse.redirect(new URL('/?auth=required', request.url), { status: 303 });
  }

  const formData = await request.formData().catch(() => null);
  const requestedTier = (formData?.get('tier') as SubscriptionTier | null) ?? 'veralify_plus';
  const plan = getPlanByTier(requestedTier);

  if (!plan?.priceEnvVar) {
    log.warn('rejected: invalid or non-purchasable plan', requestedTier);
    log.done(400);
    return NextResponse.json({ error: 'Invalid plan selected.' }, { status: 400 });
  }

  const priceId = process.env[plan.priceEnvVar];
  if (!priceId) {
    log.error('missing price id env var', plan.priceEnvVar);
    log.done(500);
    return NextResponse.json(
      { error: 'Billing is not configured on the server.' },
      { status: 500 },
    );
  }

  let stripe: ReturnType<typeof getStripe>;
  try {
    stripe = getStripe();
  } catch (err) {
    log.error('stripe not configured', err instanceof Error ? err.message : String(err));
    log.done(500);
    return NextResponse.json(
      { error: 'Billing is not configured on the server.' },
      { status: 500 },
    );
  }

  // Reuse the existing Stripe customer if we already created one for this
  // user, otherwise let Checkout create it and we persist the id afterwards
  // via the webhook (belt-and-suspenders: also try to persist it here).
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('stripe_customer_id')
    .eq('id', user.id)
    .maybeSingle();

  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: profile?.stripe_customer_id || undefined,
      customer_email: profile?.stripe_customer_id ? undefined : (user.email ?? undefined),
      client_reference_id: user.id,
      line_items: [{ price: priceId, quantity: 1 }],
      subscription_data: {
        metadata: { user_id: user.id, tier: plan.tier },
      },
      metadata: { user_id: user.id, tier: plan.tier },
      allow_promotion_codes: true,
      success_url: `${brand.websiteUrl}/dashboard?checkout=success`,
      cancel_url: `${brand.websiteUrl}/pricing?checkout=cancelled`,
    });

    if (!session.url) {
      log.error('checkout session missing url');
      log.done(502);
      return NextResponse.json({ error: 'Could not start checkout.' }, { status: 502 });
    }

    log.done(303, { userId: user.id, tier: plan.tier });
    return NextResponse.redirect(session.url, { status: 303 });
  } catch (err) {
    log.error(
      'stripe checkout session create failed',
      err instanceof Error ? err.message : String(err),
    );
    log.done(502);
    return NextResponse.json({ error: 'Could not start checkout.' }, { status: 502 });
  }
}
