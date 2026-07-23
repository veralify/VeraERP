create extension if not exists pgcrypto;

-- Profiles & subscription status
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  subscription_tier text not null default 'free',
  monthly_ai_credits integer not null default 50,
  stripe_customer_id text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint profiles_subscription_tier_check check (subscription_tier in ('free', 'veralify_plus'))
);

-- AI usage logs for analytics and guardrails
create table if not exists public.ai_usage_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  model_used text not null,
  prompt_tokens integer not null default 0,
  completion_tokens integer not null default 0,
  created_at timestamptz not null default now()
);

-- Orders (flights, eSIM, lounges)
create table if not exists public.user_orders (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  order_type text not null,
  reference_code text not null,
  amount numeric(10, 2) not null,
  currency text not null default 'USD',
  status text not null default 'completed',
  created_at timestamptz not null default now(),
  constraint user_orders_order_type_check check (order_type in ('flight', 'esim', 'lounge'))
);

create index if not exists idx_ai_usage_logs_user_id_created_at
  on public.ai_usage_logs(user_id, created_at desc);

create index if not exists idx_user_orders_user_id_created_at
  on public.user_orders(user_id, created_at desc);

create index if not exists idx_user_orders_reference_code
  on public.user_orders(reference_code);

alter table public.profiles enable row level security;
alter table public.ai_usage_logs enable row level security;
alter table public.user_orders enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_own'
  ) then
    create policy profiles_select_own
      on public.profiles for select
      to authenticated
      using (auth.uid() = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own
      on public.profiles for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_insert_own'
  ) then
    create policy profiles_insert_own
      on public.profiles for insert
      to authenticated
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'ai_usage_logs'
      and policyname = 'ai_usage_logs_select_own'
  ) then
    create policy ai_usage_logs_select_own
      on public.ai_usage_logs for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_orders'
      and policyname = 'user_orders_select_own'
  ) then
    create policy user_orders_select_own
      on public.user_orders for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_orders'
      and policyname = 'user_orders_insert_own'
  ) then
    create policy user_orders_insert_own
      on public.user_orders for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;
end
$$;

-- Auto-create profile on auth signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update
  set
    email = excluded.email,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Backfill profiles for existing auth users.
insert into public.profiles (id, email)
select id, email
from auth.users
on conflict (id) do update
set
  email = excluded.email,
  updated_at = now();
