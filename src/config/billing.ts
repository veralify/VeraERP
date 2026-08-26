/**
 * Subscription plan catalogue. `tier` must match the
 * `profiles_subscription_tier_check` constraint in Supabase
 * (supabase/migrations/20260720173000_create_profiles_usage_and_orders.sql).
 *
 * Add new paid tiers here *and* extend the DB check constraint together.
 */
export type SubscriptionTier = 'free' | 'veralify_plus';

export type BillingPlan = {
  tier: SubscriptionTier;
  name: string;
  description: string;
  priceLabel: string;
  monthlyAiCredits: number;
  features: string[];
  /** Env var name holding the live Stripe Price ID for this plan (recurring). */
  priceEnvVar?: string;
};

export const billingPlans: BillingPlan[] = [
  {
    tier: 'free',
    name: 'Free',
    description: 'Get started with the essentials.',
    priceLabel: '$0/mo',
    monthlyAiCredits: 50,
    features: ['50 AI credits / month', 'Core travel & eSIM tools', 'Community support'],
  },
  {
    tier: 'veralify_plus',
    name: 'Veralify Plus',
    description: 'More AI credits and priority perks for frequent travellers.',
    priceLabel: '$9/mo',
    monthlyAiCredits: 1000,
    features: ['1,000 AI credits / month', 'Priority support', 'Early access to new features'],
    priceEnvVar: 'STRIPE_PRICE_VERALIFY_PLUS',
  },
];

export function getPlanByTier(tier: SubscriptionTier): BillingPlan | undefined {
  return billingPlans.find((plan) => plan.tier === tier);
}

export function getPlanByPriceId(priceId: string): BillingPlan | undefined {
  return billingPlans.find((plan) => plan.priceEnvVar && process.env[plan.priceEnvVar] === priceId);
}
