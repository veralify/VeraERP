-- GDPR / UK-GDPR compliance for the waitlist.
-- Records explicit consent (proof-of-consent), origin metadata, and an
-- unsubscribe token so we can honour the right to withdraw / be forgotten.

alter table public.newsletter_subscribers
  add column if not exists consent boolean not null default false,
  add column if not exists consent_at timestamptz,
  add column if not exists consent_text text,
  add column if not exists ip_address text,
  add column if not exists user_agent text,
  add column if not exists unsubscribe_token uuid not null default gen_random_uuid();

create unique index if not exists idx_newsletter_subscribers_unsub_token
  on public.newsletter_subscribers(unsubscribe_token);

-- Lock the table down: this table contains personal data (email addresses).
-- Only privileged server contexts (service_role) may read/write it. RLS with
-- no public policies means anon/authenticated clients get zero access, while
-- service_role bypasses RLS entirely.
alter table public.newsletter_subscribers enable row level security;
