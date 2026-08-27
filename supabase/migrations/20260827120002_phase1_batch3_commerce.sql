-- Phase 1 Batch 3 commerce, subscriptions, IAP, and Stripe Connect marketplace tables.
-- Ambiguity resolved: plan catalog tables are public/auth readable product metadata; all payment, webhook, ledger, and marketplace transaction tables are server-only except subscriptions/user_entitlements self-read per §26.

create type public.billing_provider as enum ('apple', 'stripe');
create type public.billing_period as enum ('weekly', 'monthly', 'annual');
create type public.subscription_status as enum ('trialing', 'active', 'past_due', 'canceled', 'incomplete', 'incomplete_expired', 'unpaid');
create type public.iap_status as enum ('active', 'expired', 'revoked', 'grace_period');
create type public.iap_environment as enum ('production', 'sandbox');
create type public.entitlement_source as enum ('apple', 'stripe', 'admin', 'promo');
create type public.stripe_onboarding_status as enum ('pending', 'complete', 'restricted');
create type public.session_payment_status as enum ('requires_payment', 'succeeded', 'refunded', 'failed');
create type public.coach_transaction_type as enum ('charge', 'refund', 'payout', 'fee', 'adjustment');
create type public.coach_payout_status as enum ('pending', 'in_transit', 'paid', 'failed', 'cancelled');
create type public.refund_status as enum ('pending', 'succeeded', 'failed', 'canceled');

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_products (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  provider public.billing_provider not null,
  provider_product_id text not null,
  billing_period public.billing_period not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_product_id)
);

create table if not exists public.plan_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  lookup_key text not null,
  limit_value numeric,
  limit_period text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, lookup_key)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status public.subscription_status not null,
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_period_check check (current_period_end > current_period_start)
);

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  stripe_event_id text not null unique,
  event_type text not null,
  payload jsonb not null,
  processed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists public.iap_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  apple_original_transaction_id text not null unique,
  apple_transaction_id text not null unique,
  product_id text not null,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status public.iap_status not null,
  purchased_at timestamptz not null,
  expires_at timestamptz,
  environment public.iap_environment not null,
  raw_payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  lookup_key text not null,
  source public.entitlement_source not null,
  active boolean not null default false,
  limit_value numeric,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, lookup_key, source)
);

create table if not exists public.coach_stripe_accounts (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null unique references public.coach_profiles(id) on delete cascade,
  stripe_account_id text not null unique,
  onboarding_status public.stripe_onboarding_status not null default 'pending',
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coach_platform_fees (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  percentage numeric not null check (percentage >= 0 and percentage <= 100),
  effective_from timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.session_payment_intents (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.coach_sessions(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  stripe_payment_intent_id text not null unique,
  amount_cents integer not null check (amount_cents > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  platform_fee_cents integer not null check (platform_fee_cents >= 0),
  status public.session_payment_status not null default 'requires_payment',
  idempotency_key_id uuid references public.idempotency_keys(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_payment_fee_amount_check check (platform_fee_cents <= amount_cents)
);

create table if not exists public.coach_transactions (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  session_payment_intent_id uuid references public.session_payment_intents(id) on delete set null,
  type public.coach_transaction_type not null,
  amount_cents integer not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  stripe_ref text,
  idempotency_key_id uuid references public.idempotency_keys(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coach_payouts (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  stripe_payout_id text unique,
  amount_cents integer not null check (amount_cents >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status public.coach_payout_status not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  idempotency_key_id uuid references public.idempotency_keys(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coach_payouts_period_check check (period_end > period_start)
);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  session_payment_intent_id uuid not null references public.session_payment_intents(id) on delete cascade,
  stripe_refund_id text unique,
  amount_cents integer not null check (amount_cents > 0),
  reason text,
  status public.refund_status not null default 'pending',
  requested_by uuid references public.profiles(id) on delete set null,
  idempotency_key_id uuid references public.idempotency_keys(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_billing_products_plan_id on public.billing_products(plan_id);
create index if not exists idx_plan_entitlements_plan_id on public.plan_entitlements(plan_id);
create index if not exists idx_subscriptions_user_status on public.subscriptions(user_id, status);
create index if not exists idx_subscription_events_processed_created on public.subscription_events(processed, created_at);
create index if not exists idx_iap_transactions_user_status on public.iap_transactions(user_id, status);
create index if not exists idx_iap_transactions_product_id on public.iap_transactions(product_id);
create index if not exists idx_user_entitlements_user_lookup_active on public.user_entitlements(user_id, lookup_key, active);
create index if not exists idx_coach_platform_fees_coach_effective on public.coach_platform_fees(coach_id, effective_from desc);
create index if not exists idx_session_payment_intents_client_id on public.session_payment_intents(client_id);
create index if not exists idx_session_payment_intents_coach_id on public.session_payment_intents(coach_id);
create index if not exists idx_session_payment_intents_status on public.session_payment_intents(status);
create index if not exists idx_coach_transactions_coach_created on public.coach_transactions(coach_id, created_at desc);
create index if not exists idx_coach_transactions_intent_id on public.coach_transactions(session_payment_intent_id);
create index if not exists idx_coach_payouts_coach_created on public.coach_payouts(coach_id, created_at desc);
create index if not exists idx_refunds_intent_id on public.refunds(session_payment_intent_id);
create index if not exists idx_refunds_status on public.refunds(status);

create trigger set_plans_updated_at before update on public.plans for each row execute function public.set_updated_at();
create trigger set_billing_products_updated_at before update on public.billing_products for each row execute function public.set_updated_at();
create trigger set_plan_entitlements_updated_at before update on public.plan_entitlements for each row execute function public.set_updated_at();
create trigger set_subscriptions_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();
create trigger set_subscription_events_updated_at before update on public.subscription_events for each row execute function public.set_updated_at();
create trigger set_iap_transactions_updated_at before update on public.iap_transactions for each row execute function public.set_updated_at();
create trigger set_user_entitlements_updated_at before update on public.user_entitlements for each row execute function public.set_updated_at();
create trigger set_coach_stripe_accounts_updated_at before update on public.coach_stripe_accounts for each row execute function public.set_updated_at();
create trigger set_coach_platform_fees_updated_at before update on public.coach_platform_fees for each row execute function public.set_updated_at();
create trigger set_session_payment_intents_updated_at before update on public.session_payment_intents for each row execute function public.set_updated_at();
create trigger set_coach_transactions_updated_at before update on public.coach_transactions for each row execute function public.set_updated_at();
create trigger set_coach_payouts_updated_at before update on public.coach_payouts for each row execute function public.set_updated_at();
create trigger set_refunds_updated_at before update on public.refunds for each row execute function public.set_updated_at();

create or replace function public.prevent_session_payment_fee_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.platform_fee_cents <> old.platform_fee_cents then
    raise exception 'platform_fee_cents is immutable once created' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger prevent_session_payment_fee_mutation
before update on public.session_payment_intents
for each row execute function public.prevent_session_payment_fee_mutation();

alter table public.plans enable row level security;
alter table public.billing_products enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.iap_transactions enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.coach_stripe_accounts enable row level security;
alter table public.session_payment_intents enable row level security;
alter table public.coach_transactions enable row level security;
alter table public.coach_payouts enable row level security;
alter table public.coach_platform_fees enable row level security;
alter table public.refunds enable row level security;
alter table public.plans force row level security;
alter table public.billing_products force row level security;
alter table public.plan_entitlements force row level security;
alter table public.subscriptions force row level security;
alter table public.subscription_events force row level security;
alter table public.iap_transactions force row level security;
alter table public.user_entitlements force row level security;
alter table public.coach_stripe_accounts force row level security;
alter table public.session_payment_intents force row level security;
alter table public.coach_transactions force row level security;
alter table public.coach_payouts force row level security;
alter table public.coach_platform_fees force row level security;
alter table public.refunds force row level security;

create policy plans_select_active on public.plans for select to anon, authenticated using (is_active);
create policy billing_products_select_active on public.billing_products for select to anon, authenticated using (is_active and exists (select 1 from public.plans p where p.id = billing_products.plan_id and p.is_active));
create policy plan_entitlements_select_active_plan on public.plan_entitlements for select to anon, authenticated using (exists (select 1 from public.plans p where p.id = plan_entitlements.plan_id and p.is_active));
create policy subscriptions_select_own on public.subscriptions for select to authenticated using (auth.uid() = user_id);
create policy user_entitlements_select_own on public.user_entitlements for select to authenticated using (auth.uid() = user_id);

revoke select, insert, update, delete on public.subscription_events, public.iap_transactions, public.coach_stripe_accounts, public.session_payment_intents, public.coach_transactions, public.coach_payouts, public.coach_platform_fees, public.refunds from anon, authenticated;
grant select on public.plans, public.billing_products, public.plan_entitlements to anon, authenticated;
grant select on public.subscriptions, public.user_entitlements to authenticated;
