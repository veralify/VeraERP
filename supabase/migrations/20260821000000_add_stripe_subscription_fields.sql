-- Track Stripe subscription lifecycle on profiles so the webhook handler can
-- upgrade/downgrade a user's tier and reconcile state on every Stripe event.

alter table public.profiles
  add column if not exists stripe_subscription_id text;

alter table public.profiles
  add column if not exists subscription_status text;

create index if not exists idx_profiles_stripe_customer_id
  on public.profiles(stripe_customer_id);

create index if not exists idx_profiles_stripe_subscription_id
  on public.profiles(stripe_subscription_id);
