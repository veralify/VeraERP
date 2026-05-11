create extension if not exists pgcrypto;

create table if not exists public.vera_users (
  id uuid primary key default gen_random_uuid(),
  account_identifier text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
