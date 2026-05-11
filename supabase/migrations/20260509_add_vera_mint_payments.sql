create table if not exists public.vera_mint_payments (
  id uuid primary key default gen_random_uuid(),
  payment_signature text not null unique,
  wallet_address text not null,
  metadata_uri text not null,
  status text not null default 'processing',
  mint_signature text,
  asset_id text,
  tree_address text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vera_mint_payments_wallet
  on public.vera_mint_payments(wallet_address);
