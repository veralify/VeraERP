-- eSIM Orders table
-- Stores every eSIM purchased by a user via the Airalo API.
-- The iOS app also caches orders in UserDefaults (LocalOrderStore).
-- This table is the source of truth for server-side tracking.

create table if not exists public.esim_orders (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid references public.vera_users(id) on delete cascade,
  airalo_order_id             integer not null,
  airalo_order_code           text not null,
  package_id                  text not null,
  package_title               text not null,
  country_code                text not null,
  country_name                text not null,
  data_text                   text not null,
  validity_days               integer not null,
  price                       numeric(10, 2) not null,
  iccid                       text not null unique,
  lpa                         text not null,
  matching_id                 text not null,
  qrcode                      text not null,
  qrcode_url                  text,
  direct_apple_install_url    text,
  status                      text not null default 'active',
  created_at                  timestamptz not null default now()
);

create index if not exists idx_esim_orders_user_id  on public.esim_orders(user_id);
create index if not exists idx_esim_orders_iccid    on public.esim_orders(iccid);
create index if not exists idx_esim_orders_status   on public.esim_orders(status);

-- Row Level Security: users can only see their own orders
alter table public.esim_orders enable row level security;

create policy "Users can read own orders"
  on public.esim_orders for select
  using (auth.uid() = user_id);

create policy "Users can insert own orders"
  on public.esim_orders for insert
  with check (auth.uid() = user_id);
