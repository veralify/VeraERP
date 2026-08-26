import { ManageBillingButton } from '@components/billing/ManageBillingButton';
import { NewsletterControl } from '@components/dashboard/NewsletterControl';
import { getActiveBrand } from '@config/brands';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import type { Metadata } from 'next';

const brand = getActiveBrand();

export const metadata: Metadata = {
  title: `${brand.name} Dashboard`,
  description: `Admin dashboard for ${brand.name} email campaigns and operations.`,
};

async function getBillingStatus() {
  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return null;

    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('subscription_tier, stripe_customer_id')
      .eq('id', user.id)
      .maybeSingle();

    return profile ?? null;
  } catch {
    return null;
  }
}

export default async function DashboardPage() {
  const billing = await getBillingStatus();

  return (
    <main
      className="px-6 pb-40 pt-10"
      style={{ backgroundColor: 'var(--page-bg)', color: 'var(--text-main)' }}
    >
      {billing?.stripe_customer_id ? (
        <div className="mb-8 flex items-center justify-between rounded-xl border border-black/10 p-4 dark:border-white/10">
          <span className="text-sm opacity-80">
            Current plan: <strong>{billing.subscription_tier}</strong>
          </span>
          <ManageBillingButton />
        </div>
      ) : null}
      <NewsletterControl />
    </main>
  );
}
