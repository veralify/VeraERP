create extension if not exists pgcrypto;

create table if not exists public.vera_users (
  id uuid primary key default gen_random_uuid(),
  wallet_address text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vera_enfts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.vera_users(id) on delete cascade,
  wallet_address text not null,
  mint_address text not null unique,
  transaction_signature text not null unique,
  asset_name text not null,
  category text,
  serial_number text,
  description text not null,
  metadata_uri text not null,
  metadata_gateway_url text,
  photo_uris jsonb not null default '[]'::jsonb,
  fee_lamports bigint not null,
  fee_recipient text not null,
  status text not null default 'minted',
  created_at timestamptz not null default now()
);

create index if not exists idx_vera_enfts_wallet on public.vera_enfts(wallet_address);
create index if not exists idx_vera_enfts_user_id on public.vera_enfts(user_id);
