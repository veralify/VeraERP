import { getActiveBrand } from '@config/brands';
import { apiLogger } from '@lib/logger';
import { getStripe } from '@lib/stripe/server';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { NextResponse } from 'next/server';

/**
 * Opens the Stripe customer billing portal for the signed-in user so they
 * can manage or cancel their subscription and view invoices. Called via a
 * plain `<form action="/api/stripe/portal" method="POST">`.
 */
export async function POST(request: Request) {
  const log = apiLogger('/api/stripe/portal', request);
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

  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('stripe_customer_id')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile?.stripe_customer_id) {
    log.warn('rejected: no stripe customer for user', user.id);
    log.done(400);
    return NextResponse.redirect(new URL('/pricing?billing=none', request.url), { status: 303 });
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

  try {
    const portalSession = await stripe.billingPortal.sessions.create({
      customer: profile.stripe_customer_id,
      return_url: `${brand.websiteUrl}/dashboard`,
    });

    log.done(303, { userId: user.id });
    return NextResponse.redirect(portalSession.url, { status: 303 });
  } catch (err) {
    log.error(
      'stripe portal session create failed',
      err instanceof Error ? err.message : String(err),
    );
    log.done(502);
    return NextResponse.json({ error: 'Could not open billing portal.' }, { status: 502 });
  }
}
