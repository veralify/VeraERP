alter table if exists public.vera_users
  add column if not exists embedded_wallet_address text;

create index if not exists idx_vera_users_embedded_wallet_address
  on public.vera_users(embedded_wallet_address)
  where embedded_wallet_address is not null;
