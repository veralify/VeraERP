/**
 * Web subscription catalogue for the fitness pivot.
 *
 * Stripe prices are configuration, not hard-coded live billing truth. Create the
 * VERALIFY_PRO weekly/monthly/annual Stripe Prices with a 3-day trial in Stripe,
 * then set the env vars below. Display labels mirror the frozen launch spec and
 * must be reconciled with Stripe before production launch.
 */
export type SubscriptionTier = 'veralify_plus';
export type BillingCadence = 'weekly' | 'monthly' | 'annual';

export type BillingOption = {
  tier: SubscriptionTier;
  productKey: 'VERALIFY_PRO';
  cadence: BillingCadence;
  name: string;
  description: string;
  priceLabel: string;
  note: string;
  trialDays: number;
  monthlyAiCredits: number;
  features: string[];
  priceEnvVar: string;
  recommended?: boolean;
};

const proFeatures = [
  'AI food logging and verification',
  'Advanced nutrition and daily summaries',
  'Goal, progress, trend, and photo tracking',
  'Unlimited groups and community accountability',
  'Live rooms and premium live rooms',
  'Coach discovery and AI recommendations',
];

export const billingOptions: BillingOption[] = [
  {
    tier: 'veralify_plus',
    productKey: 'VERALIFY_PRO',
    cadence: 'weekly',
    name: 'Weekly',
    description: 'Flexible access for short reset periods.',
    priceLabel: '$4.99 / week',
    note: '3-day trial, then weekly billing.',
    trialDays: 3,
    monthlyAiCredits: 1000,
    features: proFeatures,
    priceEnvVar: 'STRIPE_PRICE_VERALIFY_PRO_WEEKLY',
  },
  {
    tier: 'veralify_plus',
    productKey: 'VERALIFY_PRO',
    cadence: 'monthly',
    name: 'Monthly',
    description: 'Month-to-month Pro accountability.',
    priceLabel: '$9.99 / month',
    note: '3-day trial, then monthly billing.',
    trialDays: 3,
    monthlyAiCredits: 1000,
    features: proFeatures,
    priceEnvVar: 'STRIPE_PRICE_VERALIFY_PRO_MONTHLY',
  },
  {
    tier: 'veralify_plus',
    productKey: 'VERALIFY_PRO',
    cadence: 'annual',
    name: 'Annual',
    description: 'Default launch value for long-term consistency.',
    priceLabel: '$29.99 / year',
    note: '3-day trial, then annual billing. Save 75% versus weekly.',
    trialDays: 3,
    monthlyAiCredits: 1000,
    features: proFeatures,
    priceEnvVar: 'STRIPE_PRICE_VERALIFY_PRO_ANNUAL',
    recommended: true,
  },
];

export const billingPlans = billingOptions;

export function getPlanByTier(tier: SubscriptionTier): BillingOption | undefined {
  return billingOptions.find((plan) => plan.tier === tier && plan.cadence === 'annual');
}

export function getPlanByCadence(cadence: BillingCadence): BillingOption | undefined {
  return billingOptions.find((plan) => plan.cadence === cadence);
}

export function getPlanByPriceId(priceId: string): BillingOption | undefined {
  return billingOptions.find((plan) => process.env[plan.priceEnvVar] === priceId);
}
