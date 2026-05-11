create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  brand text not null default 'default',
  source text not null default 'website',
  status text not null default 'subscribed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_newsletter_subscribers_email
  on public.newsletter_subscribers(email);

create index if not exists idx_newsletter_subscribers_brand
  on public.newsletter_subscribers(brand);
