-- Money Manager: personal finance module, ported from the standalone
-- money-manager-web-mvp-v1 prototype (Express + SQLite, single-user, no auth)
-- into a per-user, RLS-scoped domain of the main app. Table names are
-- `money_*`-prefixed to keep this bolted-on module's namespace clearly
-- separate from the fitness/coaching schema.

create type public.money_cadence as enum ('monthly', 'yearly');
create type public.money_transaction_direction as enum ('income', 'expense');
create type public.money_task_status as enum ('open', 'done');

create table public.money_income (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  amount numeric not null check (amount >= 0),
  type text not null default 'fixed',
  payday integer check (payday is null or (payday between 1 and 31)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  amount numeric not null check (amount >= 0),
  category text not null default 'Fixed',
  due_day integer check (due_day is null or (due_day between 1 and 31)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  balance numeric not null check (balance >= 0),
  apr numeric not null default 0 check (apr >= 0),
  minimum_payment numeric not null default 0 check (minimum_payment >= 0),
  due_day integer check (due_day is null or (due_day between 1 and 31)),
  priority integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_savings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  amount numeric not null default 0 check (amount >= 0),
  target_amount numeric not null default 0 check (target_amount >= 0),
  monthly_contribution numeric not null default 0 check (monthly_contribution >= 0),
  category text not null default 'General',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_settings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  key text not null,
  value text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

create table public.money_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_date date not null,
  merchant text not null,
  amount numeric not null check (amount >= 0),
  direction public.money_transaction_direction not null,
  category text not null default 'Uncategorized',
  account text not null default 'Main account',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  amount numeric not null check (amount >= 0),
  cadence public.money_cadence not null default 'monthly',
  next_charge_date date,
  trial_ends_on date,
  category text not null default 'Subscriptions',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_admin_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  category text not null default 'General',
  due_date date,
  notes text not null default '',
  status public.money_task_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.money_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  document_type text not null default 'Receipt',
  expiry_date date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_money_income_user on public.money_income(user_id);
create index idx_money_expenses_user on public.money_expenses(user_id);
create index idx_money_debts_user on public.money_debts(user_id);
create index idx_money_savings_user on public.money_savings(user_id);
create index idx_money_transactions_user_date on public.money_transactions(user_id, transaction_date desc);
create index idx_money_subscriptions_user on public.money_subscriptions(user_id);
create index idx_money_admin_tasks_user on public.money_admin_tasks(user_id, status);
create index idx_money_documents_user on public.money_documents(user_id);

create trigger set_money_income_updated_at before update on public.money_income for each row execute function public.set_updated_at();
create trigger set_money_expenses_updated_at before update on public.money_expenses for each row execute function public.set_updated_at();
create trigger set_money_debts_updated_at before update on public.money_debts for each row execute function public.set_updated_at();
create trigger set_money_savings_updated_at before update on public.money_savings for each row execute function public.set_updated_at();
create trigger set_money_settings_updated_at before update on public.money_settings for each row execute function public.set_updated_at();
create trigger set_money_transactions_updated_at before update on public.money_transactions for each row execute function public.set_updated_at();
create trigger set_money_subscriptions_updated_at before update on public.money_subscriptions for each row execute function public.set_updated_at();
create trigger set_money_admin_tasks_updated_at before update on public.money_admin_tasks for each row execute function public.set_updated_at();
create trigger set_money_documents_updated_at before update on public.money_documents for each row execute function public.set_updated_at();

alter table public.money_income enable row level security;
alter table public.money_expenses enable row level security;
alter table public.money_debts enable row level security;
alter table public.money_savings enable row level security;
alter table public.money_settings enable row level security;
alter table public.money_transactions enable row level security;
alter table public.money_subscriptions enable row level security;
alter table public.money_admin_tasks enable row level security;
alter table public.money_documents enable row level security;
alter table public.money_income force row level security;
alter table public.money_expenses force row level security;
alter table public.money_debts force row level security;
alter table public.money_savings force row level security;
alter table public.money_settings force row level security;
alter table public.money_transactions force row level security;
alter table public.money_subscriptions force row level security;
alter table public.money_admin_tasks force row level security;
alter table public.money_documents force row level security;

-- Owner-only access on every table — this is private financial data, never
-- shared with coaches, other users, or anon visitors.
create policy money_income_owner on public.money_income for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_expenses_owner on public.money_expenses for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_debts_owner on public.money_debts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_savings_owner on public.money_savings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_settings_owner on public.money_settings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_transactions_owner on public.money_transactions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_subscriptions_owner on public.money_subscriptions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_admin_tasks_owner on public.money_admin_tasks for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy money_documents_owner on public.money_documents for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.money_income, public.money_expenses, public.money_debts, public.money_savings, public.money_settings, public.money_transactions, public.money_subscriptions, public.money_admin_tasks, public.money_documents from anon;
grant select, insert, update, delete on public.money_income, public.money_expenses, public.money_debts, public.money_savings, public.money_settings, public.money_transactions, public.money_subscriptions, public.money_admin_tasks, public.money_documents to authenticated;
