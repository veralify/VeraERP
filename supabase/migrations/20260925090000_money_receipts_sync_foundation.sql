-- Receipts, sync and accounting foundation for the money module.
--
-- Shared contract for the phased build described in
-- money-manager-ios/docs/RECEIPTS_CONTRACTS.md. Every later phase builds
-- against these tables, so each phase can be developed in parallel:
--
--   Phase 0  iOS sign-in and two-way sync   (sync columns, iOS-only models)
--   Phase 1  receipt capture + AI reading   (money_receipts, categories, rules)
--   Phase 2  web dashboard + budgets        (money_budgets, reads everything)
--   Phase 3  accounting integrations        (accounting_*)
--   Phase 4  reports and extras             (mileage, fx rates, inbound email)
--
-- Sync model: ids are generated on the client (so the phone can create rows
-- offline), deletes are soft (`deleted_at`) so they reach other devices, and
-- every write takes the next value of one global sequence (`sync_seq`). A
-- client pulls "everything with sync_seq greater than my cursor", which,
-- unlike a timestamp cursor, cannot skip two rows written in the same
-- instant.

-- ---------------------------------------------------------------------------
-- Sync plumbing
-- ---------------------------------------------------------------------------

create sequence public.money_sync_seq;

grant usage on sequence public.money_sync_seq to authenticated, service_role;

create or replace function public.money_touch_sync()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  new.sync_seq = nextval('public.money_sync_seq');
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Existing tables: sync columns and fields the iOS models already have
-- ---------------------------------------------------------------------------

alter table public.money_income
  add column deleted_at timestamptz,
  add column sync_seq bigint not null default nextval('public.money_sync_seq');
alter table public.money_income
  add constraint money_income_type_check check (type in ('fixed', 'variable'));

alter table public.money_expenses
  add column deleted_at timestamptz,
  add column sync_seq bigint not null default nextval('public.money_sync_seq');

-- `local_id` mirrors DebtRecord.remoteID on iOS: the payoff engine orders by
-- it, so it has to survive a round trip unchanged.
alter table public.money_debts
  add column local_id integer,
  add column extra_payment numeric not null default 0 check (extra_payment >= 0),
  add column deleted_at timestamptz,
  add column sync_seq bigint not null default nextval('public.money_sync_seq');
create unique index money_debts_user_local_id on public.money_debts(user_id, local_id) where local_id is not null and deleted_at is null;

alter table public.money_settings
  add column deleted_at timestamptz,
  add column sync_seq bigint not null default nextval('public.money_sync_seq');

create type public.money_scope as enum ('personal', 'business');
create type public.money_transaction_source as enum ('manual', 'receipt', 'email', 'import', 'mileage');

alter table public.money_transactions
  add column currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  add column tax_amount numeric check (tax_amount is null or tax_amount >= 0),
  add column home_amount numeric check (home_amount is null or home_amount >= 0),
  add column scope public.money_scope not null default 'personal',
  add column source public.money_transaction_source not null default 'manual',
  add column receipt_id uuid,
  add column occurred_at timestamptz,
  add column deleted_at timestamptz,
  add column sync_seq bigint not null default nextval('public.money_sync_seq');

create index idx_money_transactions_sync on public.money_transactions(user_id, sync_seq);
create index idx_money_income_sync on public.money_income(user_id, sync_seq);
create index idx_money_expenses_sync on public.money_expenses(user_id, sync_seq);
create index idx_money_debts_sync on public.money_debts(user_id, sync_seq);
create index idx_money_settings_sync on public.money_settings(user_id, sync_seq);

-- The old triggers only set updated_at; the sync trigger also advances the
-- cursor, and runs on insert so a new row is pulled too.
drop trigger set_money_income_updated_at on public.money_income;
drop trigger set_money_expenses_updated_at on public.money_expenses;
drop trigger set_money_debts_updated_at on public.money_debts;
drop trigger set_money_settings_updated_at on public.money_settings;
drop trigger set_money_transactions_updated_at on public.money_transactions;
create trigger money_income_sync before insert or update on public.money_income for each row execute function public.money_touch_sync();
create trigger money_expenses_sync before insert or update on public.money_expenses for each row execute function public.money_touch_sync();
create trigger money_debts_sync before insert or update on public.money_debts for each row execute function public.money_touch_sync();
create trigger money_settings_sync before insert or update on public.money_settings for each row execute function public.money_touch_sync();
create trigger money_transactions_sync before insert or update on public.money_transactions for each row execute function public.money_touch_sync();

-- ---------------------------------------------------------------------------
-- Models that until now lived only on the phone
-- ---------------------------------------------------------------------------

-- IncomeActual: what a variable income really paid in a month.
create table public.money_income_actuals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  income_id uuid not null references public.money_income(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  amount numeric not null check (amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);

-- MoneyLoss: money gone without being planned; affects its month only.
create table public.money_losses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  occurred_on date not null,
  amount numeric not null check (amount > 0),
  reason text not null default 'other' check (reason in ('lost', 'stolen', 'fine', 'unexpected', 'other')),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);

-- DebtPayment: the payment ledger behind each debt's balance.
create table public.money_debt_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  debt_id uuid not null references public.money_debts(id) on delete cascade,
  amount numeric not null check (amount > 0),
  interest_portion numeric not null default 0 check (interest_portion >= 0),
  applied_amount numeric check (applied_amount is null or applied_amount >= 0),
  paid_on date not null,
  is_paid boolean not null default false,
  is_early_payoff boolean not null default false,
  previous_minimum numeric,
  new_minimum numeric,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);

-- MonthlySnapshot: the plan as it stood when a month began.
create table public.money_monthly_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  income numeric not null,
  expenses numeric not null,
  debt_minimums numeric not null,
  debt_balance numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);
create unique index money_monthly_snapshots_user_month on public.money_monthly_snapshots(user_id, month) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- Categories, budgets and learned merchant rules
-- ---------------------------------------------------------------------------

-- The user's categories, shared by phone, web and the AI (which must pick
-- from this list, never invent one). `key` is stable; `name` is display.
create table public.money_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  key text not null check (key ~ '^[a-z0-9_]{1,40}$'),
  name text not null,
  icon text,
  color text,
  kind text not null default 'expense' check (kind in ('expense', 'income')),
  sort_order integer not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);
create unique index money_categories_user_key on public.money_categories(user_id, key) where deleted_at is null;

-- CategoryBudget: a monthly limit per category. Editable on web and phone.
create table public.money_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category_key text not null,
  monthly_limit numeric not null check (monthly_limit > 0),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);
create unique index money_budgets_user_category on public.money_budgets(user_id, category_key) where deleted_at is null;

-- A merchant the user has corrected once is filed the same way next time,
-- before the AI is even asked. `merchant_key` is the normalised name
-- (lower-case, no punctuation or legal suffixes) — see the contracts doc.
create table public.money_merchant_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  merchant_key text not null,
  category_key text not null,
  scope public.money_scope,
  hits integer not null default 1 check (hits >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);
create unique index money_merchant_rules_user_key on public.money_merchant_rules(user_id, merchant_key) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- Receipts
-- ---------------------------------------------------------------------------

create type public.money_receipt_status as enum ('uploaded', 'processing', 'extracted', 'confirmed', 'failed');
create type public.money_receipt_source as enum ('camera', 'photo_library', 'email', 'web_upload');

create table public.money_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- Object paths inside the private `receipts` bucket, one per page:
  -- "{user_id}/{receipt_id}/1.jpg", "{user_id}/{receipt_id}/2.jpg", ...
  image_paths text[] not null default '{}',
  source public.money_receipt_source not null default 'camera',
  status public.money_receipt_status not null default 'uploaded',
  -- The gateway's response, verbatim (see ReceiptExtraction in the contract).
  extraction jsonb,
  model text,
  model_version text,
  prompt_version text,
  error_code text,
  error_message text,
  -- Set when the user confirms; the transaction then carries receipt_id back.
  transaction_id uuid references public.money_transactions(id) on delete set null,
  -- Normalised merchant/date/total, for the duplicate warning.
  merchant_key text,
  receipt_date date,
  total numeric,
  currency text check (currency is null or currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);
create index idx_money_receipts_user_created on public.money_receipts(user_id, created_at desc);
create index idx_money_receipts_duplicate on public.money_receipts(user_id, merchant_key, receipt_date, total) where deleted_at is null;

alter table public.money_transactions
  add constraint money_transactions_receipt_fk foreign key (receipt_id) references public.money_receipts(id) on delete set null;

-- Confirming a receipt = saving the transaction that points at it. The client
-- cannot write `status` (that column belongs to the gateway), so the link is
-- made here, and only for the transaction owner's own receipt.
create or replace function public.money_link_confirmed_receipt()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.receipt_id is not null
     and (tg_op = 'INSERT' or new.receipt_id is distinct from old.receipt_id) then
    update public.money_receipts
       set status = 'confirmed', transaction_id = new.id
     where id = new.receipt_id
       and user_id = new.user_id
       and status in ('extracted', 'failed', 'uploaded', 'processing');
  end if;
  return new;
end;
$$;

revoke all on function public.money_link_confirmed_receipt() from public, anon, authenticated;

create trigger money_transactions_link_receipt
  after insert or update of receipt_id on public.money_transactions
  for each row execute function public.money_link_confirmed_receipt();

-- Per-user AI usage, so scans can be capped per month.
create table public.money_receipt_usage (
  user_id uuid not null references public.profiles(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  scans integer not null default 0 check (scans >= 0),
  cost_usd numeric not null default 0,
  primary key (user_id, month)
);

-- ---------------------------------------------------------------------------
-- Phase 4 extras (tables now, so the contract is complete)
-- ---------------------------------------------------------------------------

create table public.money_mileage_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  trip_date date not null,
  origin text not null default '',
  destination text not null default '',
  distance numeric not null check (distance > 0),
  unit text not null default 'km' check (unit in ('km', 'mi')),
  rate_per_unit numeric not null check (rate_per_unit >= 0),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  purpose text not null default '',
  scope public.money_scope not null default 'business',
  transaction_id uuid references public.money_transactions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_seq bigint not null default nextval('public.money_sync_seq')
);

-- Daily reference rates (ECB), readable by any signed-in user.
create table public.fx_rates (
  rate_date date not null,
  base text not null check (base ~ '^[A-Z]{3}$'),
  quote text not null check (quote ~ '^[A-Z]{3}$'),
  rate numeric not null check (rate > 0),
  source text not null default 'ecb',
  primary key (rate_date, base, quote)
);

-- A private address per user for forwarding e-mailed receipts:
-- receipts+{token}@<inbound domain>.
create table public.money_inbound_addresses (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  token text not null unique default encode(extensions.gen_random_bytes(12), 'hex'),
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Accounting integrations
-- ---------------------------------------------------------------------------

create type public.accounting_provider as enum ('quickbooks', 'xero', 'freeagent', 'fatture_in_cloud');
create type public.accounting_connection_status as enum ('active', 'needs_reauth', 'revoked', 'error');
create type public.accounting_mapping_kind as enum ('category', 'tax_rate', 'payment_account', 'currency');
create type public.accounting_job_action as enum ('create', 'update', 'delete');
create type public.accounting_job_status as enum ('pending', 'running', 'succeeded', 'failed', 'dead');

create table public.accounting_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider public.accounting_provider not null,
  -- QuickBooks realmId, Xero tenantId, FreeAgent company url, FiC company id.
  external_company_id text not null,
  company_name text not null default '',
  country text,
  home_currency text check (home_currency is null or home_currency ~ '^[A-Z]{3}$'),
  -- Reference to the encrypted token bundle in Supabase Vault. Never exposed
  -- to clients (column privilege revoked below).
  token_secret_id uuid,
  token_expires_at timestamptz,
  status public.accounting_connection_status not null default 'active',
  sync_scope public.money_scope not null default 'business',
  auto_sync boolean not null default true,
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider, external_company_id)
);

create table public.accounting_mappings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  connection_id uuid not null references public.accounting_connections(id) on delete cascade,
  kind public.accounting_mapping_kind not null,
  -- category_key, a VAT rate like "22" / "20", "default" for the paid-from
  -- account, or an ISO currency code.
  local_key text not null,
  external_id text not null,
  external_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (connection_id, kind, local_key)
);

-- Which provider record a transaction became, per connection. Lets a retry
-- update instead of duplicating, and lets an edit find what to change.
create table public.accounting_links (
  transaction_id uuid not null references public.money_transactions(id) on delete cascade,
  connection_id uuid not null references public.accounting_connections(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  external_id text not null,
  external_type text not null,
  attachment_external_id text,
  synced_at timestamptz not null default now(),
  primary key (transaction_id, connection_id)
);

create table public.accounting_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  connection_id uuid not null references public.accounting_connections(id) on delete cascade,
  transaction_id uuid not null,
  action public.accounting_job_action not null,
  status public.accounting_job_status not null default 'pending',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_accounting_jobs_due on public.accounting_sync_jobs(status, next_attempt_at) where status in ('pending', 'failed');
create index idx_accounting_jobs_user on public.accounting_sync_jobs(user_id, created_at desc);

-- OAuth handshakes in flight (state + PKCE verifier). Service role only.
create table public.accounting_oauth_states (
  state text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider public.accounting_provider not null,
  code_verifier text,
  return_to text not null default 'web',
  expires_at timestamptz not null default now() + interval '15 minutes'
);

-- ---------------------------------------------------------------------------
-- updated_at / sync triggers for the new tables
-- ---------------------------------------------------------------------------

create trigger money_income_actuals_sync before insert or update on public.money_income_actuals for each row execute function public.money_touch_sync();
create trigger money_losses_sync before insert or update on public.money_losses for each row execute function public.money_touch_sync();
create trigger money_debt_payments_sync before insert or update on public.money_debt_payments for each row execute function public.money_touch_sync();
create trigger money_monthly_snapshots_sync before insert or update on public.money_monthly_snapshots for each row execute function public.money_touch_sync();
create trigger money_categories_sync before insert or update on public.money_categories for each row execute function public.money_touch_sync();
create trigger money_budgets_sync before insert or update on public.money_budgets for each row execute function public.money_touch_sync();
create trigger money_merchant_rules_sync before insert or update on public.money_merchant_rules for each row execute function public.money_touch_sync();
create trigger money_receipts_sync before insert or update on public.money_receipts for each row execute function public.money_touch_sync();
create trigger money_mileage_trips_sync before insert or update on public.money_mileage_trips for each row execute function public.money_touch_sync();
create trigger set_accounting_connections_updated_at before update on public.accounting_connections for each row execute function public.set_updated_at();
create trigger set_accounting_mappings_updated_at before update on public.accounting_mappings for each row execute function public.set_updated_at();
create trigger set_accounting_sync_jobs_updated_at before update on public.accounting_sync_jobs for each row execute function public.set_updated_at();

create index idx_money_income_actuals_sync on public.money_income_actuals(user_id, sync_seq);
create index idx_money_losses_sync on public.money_losses(user_id, sync_seq);
create index idx_money_debt_payments_sync on public.money_debt_payments(user_id, sync_seq);
create index idx_money_monthly_snapshots_sync on public.money_monthly_snapshots(user_id, sync_seq);
create index idx_money_categories_sync on public.money_categories(user_id, sync_seq);
create index idx_money_budgets_sync on public.money_budgets(user_id, sync_seq);
create index idx_money_merchant_rules_sync on public.money_merchant_rules(user_id, sync_seq);
create index idx_money_receipts_sync on public.money_receipts(user_id, sync_seq);
create index idx_money_mileage_trips_sync on public.money_mileage_trips(user_id, sync_seq);

-- ---------------------------------------------------------------------------
-- Row security
-- ---------------------------------------------------------------------------

alter table public.money_income_actuals enable row level security;
alter table public.money_losses enable row level security;
alter table public.money_debt_payments enable row level security;
alter table public.money_monthly_snapshots enable row level security;
alter table public.money_categories enable row level security;
alter table public.money_budgets enable row level security;
alter table public.money_merchant_rules enable row level security;
alter table public.money_receipts enable row level security;
alter table public.money_receipt_usage enable row level security;
alter table public.money_mileage_trips enable row level security;
alter table public.fx_rates enable row level security;
alter table public.money_inbound_addresses enable row level security;
alter table public.accounting_connections enable row level security;
alter table public.accounting_mappings enable row level security;
alter table public.accounting_links enable row level security;
alter table public.accounting_sync_jobs enable row level security;
alter table public.accounting_oauth_states enable row level security;

alter table public.money_income_actuals force row level security;
alter table public.money_losses force row level security;
alter table public.money_debt_payments force row level security;
alter table public.money_monthly_snapshots force row level security;
alter table public.money_categories force row level security;
alter table public.money_budgets force row level security;
alter table public.money_merchant_rules force row level security;
alter table public.money_receipts force row level security;
alter table public.money_receipt_usage force row level security;
alter table public.money_mileage_trips force row level security;
alter table public.money_inbound_addresses force row level security;
alter table public.accounting_connections force row level security;
alter table public.accounting_mappings force row level security;
alter table public.accounting_links force row level security;
alter table public.accounting_sync_jobs force row level security;
alter table public.accounting_oauth_states force row level security;

-- Private financial data: owner-only, the same as the rest of money_*.
create policy money_income_actuals_owner on public.money_income_actuals for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_losses_owner on public.money_losses for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_debt_payments_owner on public.money_debt_payments for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_monthly_snapshots_owner on public.money_monthly_snapshots for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_categories_owner on public.money_categories for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_budgets_owner on public.money_budgets for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_merchant_rules_owner on public.money_merchant_rules for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_mileage_trips_owner on public.money_mileage_trips for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Receipts: the client creates the row and may edit or soft-delete it, but
-- the extraction columns are written only by the gateway (service role), so
-- the column privileges below leave them out of the client's update grant.
create policy money_receipts_owner on public.money_receipts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Read-only to the owner; written by service-role code only.
create policy money_receipt_usage_owner_read on public.money_receipt_usage for select to authenticated using (user_id = auth.uid());
create policy money_inbound_addresses_owner_read on public.money_inbound_addresses for select to authenticated using (user_id = auth.uid());
create policy accounting_connections_owner_read on public.accounting_connections for select to authenticated using (user_id = auth.uid());
create policy accounting_links_owner_read on public.accounting_links for select to authenticated using (user_id = auth.uid());
create policy accounting_sync_jobs_owner_read on public.accounting_sync_jobs for select to authenticated using (user_id = auth.uid());
-- Mappings are edited by the user in the mapping screen.
create policy accounting_mappings_owner on public.accounting_mappings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
-- Reference data.
create policy fx_rates_read on public.fx_rates for select to authenticated using (true);
-- accounting_oauth_states: no client policy at all; service role only.

revoke all on
  public.money_income_actuals, public.money_losses, public.money_debt_payments,
  public.money_monthly_snapshots, public.money_categories, public.money_budgets,
  public.money_merchant_rules, public.money_receipts, public.money_receipt_usage,
  public.money_mileage_trips, public.fx_rates, public.money_inbound_addresses,
  public.accounting_connections, public.accounting_mappings, public.accounting_links,
  public.accounting_sync_jobs, public.accounting_oauth_states
from anon, authenticated;

grant select, insert, update, delete on
  public.money_income_actuals, public.money_losses, public.money_debt_payments,
  public.money_monthly_snapshots, public.money_categories, public.money_budgets,
  public.money_merchant_rules, public.money_mileage_trips, public.accounting_mappings
to authenticated;

grant select, insert, delete on public.money_receipts to authenticated;
grant update (image_paths, source, transaction_id, deleted_at) on public.money_receipts to authenticated;

grant select on public.money_receipt_usage, public.fx_rates, public.money_inbound_addresses,
  public.accounting_links, public.accounting_sync_jobs to authenticated;

grant select (id, user_id, provider, external_company_id, company_name, country, home_currency,
  token_expires_at, status, sync_scope, auto_sync, last_synced_at, last_error, created_at, updated_at)
  on public.accounting_connections to authenticated;
-- The user may pause auto-sync or change which scope syncs; everything else
-- about a connection is managed by the integration functions.
grant update (sync_scope, auto_sync) on public.accounting_connections to authenticated;
create policy accounting_connections_owner_update on public.accounting_connections for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant all on
  public.money_income_actuals, public.money_losses, public.money_debt_payments,
  public.money_monthly_snapshots, public.money_categories, public.money_budgets,
  public.money_merchant_rules, public.money_receipts, public.money_receipt_usage,
  public.money_mileage_trips, public.fx_rates, public.money_inbound_addresses,
  public.accounting_connections, public.accounting_mappings, public.accounting_links,
  public.accounting_sync_jobs, public.accounting_oauth_states
to service_role;

-- ---------------------------------------------------------------------------
-- Storage: private receipts bucket, one folder per user
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'application/pdf'])
on conflict (id) do nothing;

create policy receipts_owner_read on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy receipts_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy receipts_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
