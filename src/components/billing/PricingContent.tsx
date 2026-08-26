import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { UpgradeButton } from '@components/billing/UpgradeButton';
import { billingPlans } from '@config/billing';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';

/**
 * Fetches the signed-in user's current tier (if any) so the pricing page can
 * highlight their active plan and swap the CTA to "Manage billing".
 */
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

    return profile?.subscription_tier ?? 'free';
  } catch {
    return null;
  }
}

export async function PricingContent() {
  const currentTier = await getCurrentTier();

  return (
    <main
      className="mx-auto max-w-5xl px-6 pb-40 pt-16"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      <div className="mb-12 text-center">
        <h1 className="text-3xl font-bold sm:text-4xl">Pricing</h1>
        <p className="mt-3 text-base opacity-80">
          Simple plans that scale with how much you travel.
        </p>
      </div>

      <div className="grid gap-6 sm:grid-cols-2">
        {billingPlans.map((plan) => {
          const isCurrent = currentTier === plan.tier;
          return (
            <div
              key={plan.tier}
              className="flex flex-col rounded-2xl border border-black/10 p-8 dark:border-white/10"
            >
              <h2 className="text-xl font-semibold">{plan.name}</h2>
              <p className="mt-2 text-sm opacity-70">{plan.description}</p>
              <p className="mt-6 text-3xl font-bold">{plan.priceLabel}</p>

              <ul className="mt-6 flex-1 space-y-2 text-sm">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-2">
                    <span aria-hidden="true">✓</span>
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>

              <div className="mt-8">
                {isCurrent ? (
                  plan.tier === 'free' ? (
                    <span className="inline-flex items-center justify-center rounded-full border border-current px-6 py-3 text-sm font-semibold opacity-60">
                      Current plan
                    </span>
                  ) : (
                    <ManageBillingButton label="Manage billing" />
                  )
                ) : plan.priceEnvVar ? (
                  <UpgradeButton tier={plan.tier} label={`Upgrade to ${plan.name}`} />
                ) : (
                  <span className="inline-flex items-center justify-center rounded-full border border-current px-6 py-3 text-sm font-semibold opacity-60">
                    Included
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </main>
  );
}
