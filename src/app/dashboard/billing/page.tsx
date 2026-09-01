import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { UpgradeButton } from '@components/billing/UpgradeButton';
import { Card, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { billingOptions } from '@config/billing';
import { getUserEntitlements } from '@lib/api/entitlements';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Billing' };

type BillingProfile = {
  subscription_status: string | null;
  subscription_tier: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
};

export default async function BillingPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const [{ data: profile }, entitlements] = await Promise.all([
    supabase
      .from('profiles')
      .select('subscription_tier, subscription_status, stripe_customer_id, stripe_subscription_id')
      .eq('id', user.id)
      .maybeSingle(),
    getUserEntitlements(user.id).catch(() => []),
  ]);
  const billing = profile as BillingProfile | null;
  const hasPortal = Boolean(billing?.stripe_customer_id);
  const hasPro = entitlements.some((entitlement) => entitlement.lookup_key === 'VERALIFY_PRO');

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Billing"
        title="Subscription and entitlements"
        body="Web digital subscriptions use Stripe Billing. iOS purchases stay on Apple In-App Purchase and both normalize into entitlements."
      />
      <div className="grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Card>
            <h2 className="text-xl font-bold">Current plan</h2>
            <dl className="mt-5 grid gap-4 text-sm sm:grid-cols-2">
              <div>
                <dt className="text-vera-fg-muted">Plan</dt>
                <dd className="mt-1 font-semibold">
                  {hasPro ? 'VERALIFY PRO' : 'No active Pro entitlement'}
                </dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Profile status</dt>
                <dd className="mt-1 font-semibold">
                  {billing?.subscription_status ?? 'Unavailable'}
                </dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Web Stripe customer</dt>
                <dd className="mt-1 font-semibold">
                  {billing?.stripe_customer_id ? 'Connected' : 'Not created'}
                </dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Subscription record</dt>
                <dd className="mt-1 font-semibold">
                  {billing?.stripe_subscription_id ? 'Present' : 'Not present'}
                </dd>
              </div>
            </dl>
            <div className="mt-6">
              {hasPortal ? (
                <ManageBillingButton className="btn-apple" />
              ) : (
                <a className="btn-apple-secondary" href="#checkout">
                  Choose a web plan
                </a>
              )}
            </div>
          </Card>

          <Card>
            <h2 className="text-xl font-bold">Active entitlements</h2>
            {entitlements.length ? (
              <div className="mt-4 divide-y divide-vera-border">
                {entitlements.map((entitlement) => (
                  <article key={entitlement.id} className="py-3 text-sm">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="font-semibold">{entitlement.lookup_key}</p>
                      <p className="rounded-full bg-vera-success/15 px-3 py-1 text-xs font-semibold text-vera-success">
                        {entitlement.source}
                      </p>
                    </div>
                    <p className="mt-1 text-vera-fg-muted">
                      {entitlement.expires_at
                        ? `Expires ${entitlement.expires_at.slice(0, 10)}`
                        : 'No expiry'}
                      {entitlement.limit_value === null
                        ? ''
                        : ` · Limit ${entitlement.limit_value}`}
                    </p>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState
                title="No active entitlements"
                body="Start a Pro trial on web or restore an iOS subscription to unlock the member experience."
              />
            )}
          </Card>
        </div>

        <Card className="scroll-mt-24" id="checkout">
          <h2 className="text-xl font-bold">Start Veralify Pro on web</h2>
          <p className="mt-2 text-sm text-vera-fg-muted">
            Each option starts a Stripe Checkout subscription with the configured 3-day trial.
          </p>
          <div className="mt-5 space-y-4">
            {billingOptions.map((plan) => (
              <article
                key={plan.cadence}
                className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="font-bold">{plan.name}</p>
                    <p className="mt-1 text-2xl font-black">{plan.priceLabel}</p>
                    <p className="mt-1 text-sm text-vera-fg-muted">{plan.note}</p>
                  </div>
                  {plan.recommended ? (
                    <span className="rounded-full bg-vera-secondary px-3 py-1 text-xs font-bold text-vera-on-secondary">
                      Default
                    </span>
                  ) : null}
                </div>
                <div className="mt-4">
                  <UpgradeButton
                    tier={plan.tier}
                    cadence={plan.cadence}
                    label="Start checkout"
                    className="btn-apple w-full"
                  />
                </div>
              </article>
            ))}
          </div>
        </Card>
      </div>
    </main>
  );
}
