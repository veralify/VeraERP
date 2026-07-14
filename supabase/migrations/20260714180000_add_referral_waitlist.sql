-- Viral referral waitlist: each subscriber gets a shareable referral_code.
-- Inviting friends increments referral_count, which moves them up the ranking.

alter table public.newsletter_subscribers
  add column if not exists referral_code text,
  add column if not exists referred_by text,
  add column if not exists referral_count integer not null default 0;

-- Backfill codes for existing rows, then enforce default + uniqueness.
update public.newsletter_subscribers
  set referral_code = substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)
  where referral_code is null;

alter table public.newsletter_subscribers
  alter column referral_code set default substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

alter table public.newsletter_subscribers
  alter column referral_code set not null;

create unique index if not exists idx_newsletter_subscribers_ref_code
  on public.newsletter_subscribers(referral_code);

create index if not exists idx_newsletter_subscribers_referral_count
  on public.newsletter_subscribers(referral_count desc);

-- 1-based waitlist position: ranked by referral_count desc, then signup time asc.
create or replace function public.waitlist_position(p_email text)
returns integer
language sql
stable
as $$
  select count(*) + 1
  from public.newsletter_subscribers s
  cross join (
    select brand, referral_count, created_at
    from public.newsletter_subscribers
    where email = p_email
    limit 1
  ) me
  where s.brand = me.brand
    and s.status = 'subscribed'
    and (
      s.referral_count > me.referral_count
      or (s.referral_count = me.referral_count and s.created_at < me.created_at)
    );
$$;

-- Credit a referrer when someone joins via their link.
create or replace function public.increment_referral(p_code text)
returns void
language sql
as $$
  update public.newsletter_subscribers
  set referral_count = referral_count + 1, updated_at = now()
  where referral_code = p_code;
$$;

-- Server-only: prevent public/anon from gaming referral counts via PostgREST RPC.
revoke execute on function public.increment_referral(text) from public, anon, authenticated;
grant execute on function public.increment_referral(text) to service_role;
revoke execute on function public.waitlist_position(text) from public, anon, authenticated;
grant execute on function public.waitlist_position(text) to service_role;
