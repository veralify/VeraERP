create table if not exists public.crm_tickets (
  id uuid primary key default gen_random_uuid(),
  brand text not null default 'default',
  title text not null,
  description text,
  status text not null default 'open',
  priority text not null default 'normal',
  asset_id text,
  subject_user_id uuid not null references public.vera_users(id) on delete restrict,
  assigned_to uuid references public.vera_users(id) on delete set null,
  created_by_user_id uuid references public.vera_users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_crm_tickets_brand_created_at
  on public.crm_tickets(brand, created_at desc);

create table if not exists public.crm_notes (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.crm_tickets(id) on delete cascade,
  body text not null,
  author_user_id uuid references public.vera_users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_crm_notes_ticket_id
  on public.crm_notes(ticket_id, created_at);

create table if not exists public.crm_actions (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.crm_tickets(id) on delete cascade,
  title text not null,
  details text,
  status text not null default 'pending',
  due_at timestamptz,
  owner_user_id uuid references public.vera_users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_crm_actions_ticket_id
  on public.crm_actions(ticket_id, created_at);
