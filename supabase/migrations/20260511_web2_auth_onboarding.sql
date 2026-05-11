alter table if exists public.vera_users
  add column if not exists privy_user_id text,
  add column if not exists social_provider text,
  add column if not exists social_user_id text,
  add column if not exists email text,
  add column if not exists phone text,
  add column if not exists display_name text;

create unique index if not exists idx_vera_users_privy_user_id
  on public.vera_users(privy_user_id)
  where privy_user_id is not null;

create unique index if not exists idx_vera_users_social_identity
  on public.vera_users(social_provider, social_user_id)
  where social_provider is not null and social_user_id is not null;

create table if not exists public.registered_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.vera_users(id) on delete cascade,
  wallet_address text not null unique,
  wallet_type text not null default 'embedded',
  auth_provider text not null default 'privy',
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_registered_devices_primary_per_user
  on public.registered_devices(user_id)
  where is_primary;
