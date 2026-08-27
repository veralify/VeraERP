import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Billing' };

async function getBilling() {
  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return null;
    const { data } = await supabaseAdmin
      .from('profiles')
      .select('subscription_tier, subscription_status, stripe_customer_id')
      .eq('id', user.id)
      .maybeSingle();
    return data;
  } catch {
    return null;
  }
}

export default async function BillingPage() {
  const billing = await getBilling();
  const hasPortal = Boolean(billing?.stripe_customer_id);
  return (
    <main className="px-4 py-8 lg:px-8">
      <section className="mb-8">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
          Billing
        </p>
        <h1 className="mt-2 text-3xl font-black tracking-tight sm:text-5xl">Subscription</h1>
        <p className="mt-3 max-w-2xl text-vera-fg-muted">
          Veralify Pro is the single paid tier. Manage web billing through Stripe.
        </p>
      </section>
      <div className="rounded-vera-2xl border border-vera-border bg-vera-surface p-8">
        <dl className="grid gap-4 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-vera-fg-muted">Tier</dt>
            <dd className="mt-1 font-semibold">
              {billing?.subscription_tier === 'veralify_plus'
                ? 'VERALIFY PRO'
                : 'No active Pro subscription'}
            </dd>
          </div>
          <div>
            <dt className="text-vera-fg-muted">Status</dt>
            <dd className="mt-1 font-semibold">{billing?.subscription_status ?? 'Unavailable'}</dd>
          </div>
        </dl>
        <div className="mt-8">
          {hasPortal ? (
            <ManageBillingButton className="btn-apple" />
          ) : (
            <a className="btn-apple" href="/pricing">
              Start 3-day Pro trial
            </a>
          )}
        </div>
      </div>
    </main>
  );
}
