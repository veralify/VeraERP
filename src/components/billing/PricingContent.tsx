import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { UpgradeButton } from '@components/billing/UpgradeButton';
import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { FAQ } from '@components/marketing/SitePrimitives';
import { billingOptions } from '@config/billing';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { Check } from 'lucide-react';

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
    <main className="relative isolate overflow-hidden bg-vera-bg px-6 pb-28 pt-16 text-vera-fg">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top,color-mix(in_srgb,var(--vera-color-primary)_18%,transparent),transparent_38rem)]" />
      <Reveal className="mx-auto max-w-4xl text-center" variants={fadeUp}>
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
      </Reveal>

      <StaggerGroup className="mx-auto mt-14 grid max-w-6xl gap-5 lg:grid-cols-3">
        {billingOptions.map((plan) => (
          <StaggerItem
            key={plan.cadence}
            as="article"
            className={`relative flex flex-col rounded-vera-2xl border p-6 transition-transform duration-200 hover:-translate-y-1 ${
              plan.recommended
                ? 'border-vera-primary bg-vera-surface shadow-[var(--vera-shadow-glow)]'
                : 'border-vera-border bg-vera-surface shadow-[var(--vera-shadow-sm)]'
            }`}
          >
            {plan.recommended ? (
              <span className="absolute right-5 top-5 rounded-full bg-vera-secondary px-3 py-1 text-xs font-bold text-vera-on-secondary">
                Best value
              </span>
            ) : null}
            <p className="text-sm font-semibold text-vera-primary">VERALIFY PRO</p>
            <h2 className="mt-3 text-2xl font-bold">{plan.name}</h2>
            <p className="mt-2 text-sm text-vera-fg-muted">{plan.description}</p>
            <p className="mt-6 text-4xl font-black tracking-tight">{plan.priceLabel}</p>
            <p className="mt-2 text-sm text-vera-fg-muted">{plan.note}</p>
            <ul className="mt-6 flex-1 space-y-3 text-sm">
              {plan.features.map((feature) => (
                <li key={feature} className="flex gap-2.5">
                  <Check className="mt-0.5 h-4 w-4 shrink-0 text-vera-success" strokeWidth={2.5} />
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
          </StaggerItem>
        ))}
      </StaggerGroup>

      <FAQ
        title="Pricing FAQ"
        items={[
          {
            question: 'What is included?',
            answer:
              'Every consumer Pro entitlement: AI food logging, advanced AI, nutrition, daily summaries, progress trends, groups, live rooms, and coach discovery.',
          },
          {
            question: 'How does the trial work?',
            answer:
              'The 3-day trial grants full Pro access. If it lapses without conversion, historical data remains read-only and Pro actions route to billing.',
          },
          {
            question: 'Can I cancel anytime?',
            answer:
              'Yes. Web subscribers manage cancellation and payment methods through the Stripe billing portal.',
          },
          {
            question: 'What about iOS purchases?',
            answer:
              'Digital subscriptions purchased in the iOS app are sold through Apple In-App Purchase and restored with the App Store account.',
          },
        ]}
      />
    </main>
  );
}
