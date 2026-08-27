-- Phase 1 Batch 1 identity domain.
-- Existing legacy public.profiles is extended in-place to preserve waitlist/auth/Stripe behavior.

alter table public.profiles
  add column if not exists username text,
  add column if not exists display_name text,
  add column if not exists avatar_path text,
  add column if not exists bio text,
  add column if not exists height_cm numeric,
  add column if not exists activity_level public.profile_activity_level,
  add column if not exists timezone text,
  add column if not exists date_of_birth date,
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists is_public boolean not null default false;

update public.profiles
set username = lower(regexp_replace(coalesce(split_part(email, '@', 1), 'user_' || replace(id::text, '-', '')), '[^a-z0-9_]+', '_', 'g'))
where username is null;

with numbered as (
  select id, username, row_number() over (partition by username order by created_at, id) as rn
  from public.profiles
)
update public.profiles p
set username = left(numbered.username, 55) || '_' || substr(replace(p.id::text, '-', ''), 1, 8)
from numbered
where p.id = numbered.id and numbered.rn > 1;

alter table public.profiles
  alter column username set not null;

create unique index if not exists profiles_username_key on public.profiles (username);

alter table public.profiles
  add constraint profiles_username_format_check check (username ~ '^[a-z0-9_]{3,64}$') not valid,
  add constraint profiles_height_cm_check check (height_cm is null or (height_cm >= 50 and height_cm <= 272)) not valid;

alter table public.profiles validate constraint profiles_username_format_check;
alter table public.profiles validate constraint profiles_height_cm_check;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create table if not exists public.profile_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  dietary_preferences jsonb not null default '{}'::jsonb,
  fitness_preferences jsonb not null default '{}'::jsonb,
  notification_preferences jsonb not null default '{}'::jsonb,
  ai_preferences jsonb not null default '{}'::jsonb,
  units public.units_system not null default 'metric',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_privacy (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  profile_visibility public.privacy_visibility not null default 'private',
  progress_visibility public.privacy_visibility not null default 'private',
  nutrition_visibility public.privacy_visibility not null default 'private',
  weight_visibility public.privacy_visibility not null default 'private',
  activity_visibility public.privacy_visibility not null default 'private',
  coach_data_visibility public.privacy_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android', 'web')),
  push_token text,
  app_version text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_devices_push_token_unique unique (push_token)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self_check check (blocker_id <> blocked_id)
);

create index if not exists idx_profile_preferences_user_id on public.profile_preferences(user_id);
create index if not exists idx_profile_privacy_user_id on public.profile_privacy(user_id);
create index if not exists idx_user_devices_user_id on public.user_devices(user_id);
create index if not exists idx_user_blocks_blocked_id on public.user_blocks(blocked_id);
create index if not exists idx_profiles_is_public_username on public.profiles(is_public, username);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  base_username text;
begin
  base_username := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1), 'user_' || substr(replace(new.id::text, '-', ''), 1, 12)), '[^a-z0-9_]+', '_', 'g'));
  if length(base_username) < 3 then
    base_username := 'user_' || substr(replace(new.id::text, '-', ''), 1, 12);
  end if;

  insert into public.profiles (id, email, username, display_name)
  values (new.id, new.email, left(base_username, 55) || '_' || substr(replace(new.id::text, '-', ''), 1, 8), new.raw_user_meta_data ->> 'display_name')
  on conflict (id) do update
  set email = excluded.email,
      updated_at = now();

  insert into public.profile_preferences (user_id) values (new.id) on conflict do nothing;
  insert into public.profile_privacy (user_id) values (new.id) on conflict do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.profile_preferences enable row level security;
alter table public.profile_privacy enable row level security;
alter table public.user_devices enable row level security;
alter table public.user_blocks enable row level security;

alter table public.profiles force row level security;
alter table public.profile_preferences force row level security;
alter table public.profile_privacy force row level security;
alter table public.user_devices force row level security;
alter table public.user_blocks force row level security;

drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (auth.uid() = id);
create policy profiles_insert_own on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy profiles_update_own on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy profile_preferences_all_own on public.profile_preferences for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy profile_privacy_all_own on public.profile_privacy for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy user_devices_all_own on public.user_devices for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy user_blocks_all_blocker on public.user_blocks for all to authenticated using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);
create policy user_blocks_select_blocked on public.user_blocks for select to authenticated using (auth.uid() = blocked_id);

create or replace view public.public_profiles
with (security_barrier = true)
as
select id, username, display_name, avatar_path, bio, created_at
from public.profiles
where is_public = true;

grant select on public.public_profiles to anon, authenticated;
grant select, insert, update, delete on public.profile_preferences, public.profile_privacy, public.user_devices, public.user_blocks to authenticated;
grant select, insert, update on public.profiles to authenticated;
