-- M0.2 (docs/EXECUTION_PLAN.md): coaches currently need a paid VERALIFY_COACH
-- entitlement before they can create a profile or start Stripe Connect
-- onboarding, which deadlocks marketplace bootstrap — no coach pays to join a
-- marketplace with no clients. Replace the paid gate with an invite allowlist
-- so founding coaches can be admitted for free; the paid entitlement remains a
-- second, independent way to qualify (see src/lib/api/coachAccess.ts).

create extension if not exists citext;

create table public.coach_invites (
  id uuid primary key default gen_random_uuid(),
  email citext not null unique,
  invited_by uuid references auth.users(id) on delete set null,
  claimed_by uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint coach_invites_claimed_check check (
    (claimed_by is null) = (claimed_at is null)
  )
);

create index idx_coach_invites_email on public.coach_invites(email);

alter table public.coach_invites enable row level security;
alter table public.coach_invites force row level security;

-- Authenticated users may only see whether *their own* email has an invite —
-- never the full allowlist, never another visitor's invite status.
create policy coach_invites_select_own_email on public.coach_invites
  for select to authenticated
  using (email = (select auth.jwt() ->> 'email')::citext);

revoke all on public.coach_invites from anon, authenticated;
grant select on public.coach_invites to authenticated;
