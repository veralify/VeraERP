import type { BillingCadence, SubscriptionTier } from '@config/billing';

type UpgradeButtonProps = {
  tier: SubscriptionTier;
  cadence?: BillingCadence;
  label?: string;
  className?: string;
};

export function UpgradeButton({
  tier,
  cadence = 'annual',
  label = 'Start trial',
  className,
}: UpgradeButtonProps) {
  return (
    <form action="/api/stripe/checkout" method="POST">
      <input type="hidden" name="tier" value={tier} />
      <input type="hidden" name="cadence" value={cadence} />
      <button
        type="submit"
        className={
          className ??
          'inline-flex min-h-11 items-center justify-center rounded-full bg-vera-primary px-6 py-3 text-sm font-semibold text-vera-on-primary transition hover:bg-vera-primary-strong focus:outline focus:outline-3 focus:outline-vera-focus'
        }
      >
        {label}
      </button>
    </form>
  );
}
