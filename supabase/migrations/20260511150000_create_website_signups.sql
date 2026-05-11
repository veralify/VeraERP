create table if not exists public.website_signups (
  id uuid primary key default gen_random_uuid(),
  brand text not null default 'default',
  full_name text,
  email text not null,
  company text,
  message text,
  source text not null default 'website-signup',
  status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_website_signups_email_brand
  on public.website_signups(email, brand);
