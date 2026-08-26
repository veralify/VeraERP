type ManageBillingButtonProps = {
  label?: string;
  className?: string;
};

/**
 * Posts to the Stripe billing portal route so a signed-in subscriber can
 * manage payment methods, view invoices, or cancel their plan.
 */
export function ManageBillingButton({
  label = 'Manage billing',
  className,
}: ManageBillingButtonProps) {
  return (
    <form action="/api/stripe/portal" method="POST">
      <button
        type="submit"
        className={
          className ??
          'inline-flex items-center justify-center rounded-full border border-current px-6 py-3 text-sm font-semibold transition hover:opacity-80'
        }
      >
        {label}
      </button>
    </form>
  );
}
