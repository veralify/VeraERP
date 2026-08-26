import type { SubscriptionTier } from '@config/billing';

type UpgradeButtonProps = {
  tier: SubscriptionTier;
  label?: string;
  className?: string;
};

/**
 * Posts straight to the Stripe checkout route so upgrading works without
 * client-side JS. Renders as a plain form + submit button styled as a link.
 */
export function UpgradeButton({ tier, label = 'Upgrade', className }: UpgradeButtonProps) {
  return (
    <form action="/api/stripe/checkout" method="POST">
      <input type="hidden" name="tier" value={tier} />
      <button
        type="submit"
        className={
          className ??
          'inline-flex items-center justify-center rounded-full bg-[var(--brand-primary,#3B82F6)] px-6 py-3 text-sm font-semibold text-white transition hover:opacity-90'
        }
      >
        {label}
      </button>
    </form>
  );
}
