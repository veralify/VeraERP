import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { UpgradeButton } from '@components/billing/UpgradeButton';
import { billingOptions } from '@config/billing';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';

async function getCurrentTier(): Promise<string | null> {
  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return null;
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('subscription_tier')
      .eq('id', user.id)
      .maybeSingle();
    return profile?.subscription_tier ?? null;
  } catch {
    return null;
  }
}

export async function PricingContent() {
  const currentTier = await getCurrentTier();
  const isPro = currentTier === 'veralify_plus';

  return (
    <main className="bg-vera-bg px-6 pb-28 pt-16 text-vera-fg">
      <section className="mx-auto max-w-4xl text-center">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
          Pricing
        </p>
        <h1 className="mt-3 text-4xl font-black tracking-tight sm:text-6xl">
          Veralify Pro unlocks everything.
        </h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg leading-8 text-vera-fg-muted">
          No free tier. Your 3-day trial includes AI food scanning, insights, unlimited groups, live
          rooms, progress analytics, and coach discovery.
        </p>
      </section>

      <section className="mx-auto mt-14 grid max-w-6xl gap-5 lg:grid-cols-3">
        {billingOptions.map((plan) => (
          <article
            key={plan.cadence}
            className="relative flex flex-col rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)]"
          >
            {plan.recommended ? (
              <span className="absolute right-5 top-5 rounded-full bg-vera-secondary px-3 py-1 text-xs font-bold text-vera-on-secondary">
                Default
              </span>
            ) : null}
            <p className="text-sm font-semibold text-vera-primary">VERALIFY PRO</p>
            <h2 className="mt-3 text-2xl font-bold">{plan.name}</h2>
            <p className="mt-2 text-sm text-vera-fg-muted">{plan.description}</p>
            <p className="mt-6 text-4xl font-black tracking-tight">{plan.priceLabel}</p>
            <p className="mt-2 text-sm text-vera-fg-muted">{plan.note}</p>
            <ul className="mt-6 flex-1 space-y-3 text-sm">
              {plan.features.map((feature) => (
                <li key={feature} className="flex gap-2">
                  <span aria-hidden="true" className="text-vera-success">
                    ✓
                  </span>
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
            <div className="mt-8">
              {isPro ? (
                <ManageBillingButton
                  label="Manage billing"
                  className="btn-apple-secondary w-full"
                />
              ) : (
                <UpgradeButton
                  tier={plan.tier}
                  cadence={plan.cadence}
                  label="Start 3-day trial"
                  className="btn-apple w-full"
                />
              )}
            </div>
          </article>
        ))}
      </section>

      <section className="mx-auto mt-16 max-w-4xl rounded-vera-2xl border border-vera-border bg-vera-bg-subtle p-8">
        <h2 className="text-2xl font-bold">FAQ</h2>
        <div className="mt-6 grid gap-5 md:grid-cols-2">
          {[
            [
              'What is included?',
              'Every consumer Pro entitlement: AI food logging, advanced AI, nutrition, daily summaries, progress trends, groups, live rooms, and coach discovery.',
            ],
            [
              'How does the trial work?',
              'The 3-day trial grants full Pro access. If it lapses without conversion, historical data remains read-only and Pro actions route to billing.',
            ],
            [
              'Can I cancel anytime?',
              'Yes. Web subscribers manage cancellation and payment methods through the Stripe billing portal.',
            ],
            [
              'What about iOS purchases?',
              'Digital subscriptions purchased in the iOS app are sold through Apple In-App Purchase and restored with the App Store account.',
            ],
          ].map(([question, answer]) => (
            <div key={question}>
              <h3 className="font-semibold">{question}</h3>
              <p className="mt-2 text-sm leading-6 text-vera-fg-muted">{answer}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
