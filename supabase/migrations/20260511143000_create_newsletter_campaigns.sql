create table if not exists public.newsletter_campaigns (
  id uuid primary key default gen_random_uuid(),
  created_by_user_id uuid references public.vera_users(id) on delete set null,
  brand text not null default 'default',
  subject text not null,
  body text not null,
  status text not null default 'draft',
  target_count integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  provider text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_newsletter_campaigns_created_at
  on public.newsletter_campaigns(created_at desc);

create table if not exists public.newsletter_campaign_deliveries (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.newsletter_campaigns(id) on delete cascade,
  subscriber_email text not null,
  status text not null,
  provider_message_id text,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists idx_newsletter_campaign_deliveries_campaign_id
  on public.newsletter_campaign_deliveries(campaign_id);
