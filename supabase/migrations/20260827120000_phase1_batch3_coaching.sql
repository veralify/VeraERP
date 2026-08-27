-- Phase 1 Batch 3 coaching domain.
-- Ambiguity resolved: coach/client relationships and permissions are server-managed; clients and coaches can read relationship/session state, but permission changes are not client-writable.

create type public.coach_verification_status as enum ('pending', 'verified', 'rejected', 'suspended');
create type public.coach_client_status as enum ('pending', 'active', 'paused', 'ended', 'cancelled');
create type public.coach_session_status as enum ('draft', 'available', 'booked', 'confirmed', 'completed', 'cancelled');
create type public.coach_session_type as enum ('video', 'audio', 'in_person');
create type public.booking_status as enum ('pending', 'payment_required', 'paid', 'confirmed', 'completed', 'cancelled', 'refunded');
create type public.booking_payment_method as enum ('stripe');
create type public.session_note_visibility as enum ('coach_private', 'client_shared');
create type public.coach_review_status as enum ('published', 'hidden', 'removed');

create table if not exists public.coach_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  headline text,
  bio text,
  specialties text[] not null default '{}',
  certifications jsonb not null default '[]'::jsonb,
  years_experience integer check (years_experience is null or years_experience >= 0),
  hourly_rate numeric check (hourly_rate is null or hourly_rate >= 0),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  location text,
  online_only boolean not null default true,
  verification_status public.coach_verification_status not null default 'pending',
  rating numeric not null default 0 check (rating >= 0 and rating <= 5),
  review_count integer not null default 0 check (review_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coach_specialties (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  specialty text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_id, specialty)
);

create table if not exists public.coach_clients (
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  status public.coach_client_status not null default 'pending',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (coach_id, client_id),
  constraint coach_clients_not_self_check check (coach_id <> client_id),
  constraint coach_clients_ended_check check ((status in ('ended', 'cancelled') and ended_at is not null) or (status not in ('ended', 'cancelled')))
);

create table if not exists public.coach_client_permissions (
  coach_id uuid not null,
  client_id uuid not null,
  nutrition boolean not null default false,
  weight boolean not null default false,
  measurements boolean not null default false,
  goals boolean not null default true,
  progress_photos boolean not null default false,
  activity boolean not null default false,
  mood boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (coach_id, client_id),
  foreign key (coach_id, client_id) references public.coach_clients(coach_id, client_id) on delete cascade
);

create table if not exists public.coach_availability (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  timezone text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coach_availability_time_check check (end_time > start_time)
);

create table if not exists public.coach_sessions (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  client_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  session_type public.coach_session_type not null default 'video',
  scheduled_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes > 0),
  status public.coach_session_status not null default 'available',
  agora_channel text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.session_bookings (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.coach_sessions(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  status public.booking_status not null default 'pending',
  payment_method public.booking_payment_method not null default 'stripe',
  booked_at timestamptz not null default now(),
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, client_id),
  constraint session_bookings_cancelled_check check ((status = 'cancelled' and cancelled_at is not null) or status <> 'cancelled')
);

create table if not exists public.session_notes (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.coach_sessions(id) on delete cascade,
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  content text not null,
  visibility public.session_note_visibility not null default 'coach_private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coach_reviews (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.coach_profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review text,
  status public.coach_review_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_id, client_id)
);

alter table public.live_rooms
  add constraint live_rooms_coach_session_fk foreign key (coach_session_id) references public.coach_sessions(id) on delete cascade;

create index if not exists idx_coach_profiles_verification_status on public.coach_profiles(verification_status);
create index if not exists idx_coach_specialties_coach_id on public.coach_specialties(coach_id);
create index if not exists idx_coach_specialties_specialty on public.coach_specialties(specialty);
create index if not exists idx_coach_clients_coach_status on public.coach_clients(coach_id, status);
create index if not exists idx_coach_clients_client_status on public.coach_clients(client_id, status);
create index if not exists idx_coach_availability_coach_active on public.coach_availability(coach_id, is_active);
create index if not exists idx_coach_sessions_coach_scheduled on public.coach_sessions(coach_id, scheduled_at);
create index if not exists idx_coach_sessions_client_scheduled on public.coach_sessions(client_id, scheduled_at);
create index if not exists idx_session_bookings_client_booked on public.session_bookings(client_id, booked_at desc);
create index if not exists idx_session_bookings_session_id on public.session_bookings(session_id);
create index if not exists idx_session_notes_session_id on public.session_notes(session_id);
create index if not exists idx_session_notes_coach_id on public.session_notes(coach_id);
create index if not exists idx_coach_reviews_coach_status on public.coach_reviews(coach_id, status);
create index if not exists idx_coach_reviews_client_id on public.coach_reviews(client_id);

create trigger set_coach_profiles_updated_at before update on public.coach_profiles for each row execute function public.set_updated_at();
create trigger set_coach_specialties_updated_at before update on public.coach_specialties for each row execute function public.set_updated_at();
create trigger set_coach_clients_updated_at before update on public.coach_clients for each row execute function public.set_updated_at();
create trigger set_coach_client_permissions_updated_at before update on public.coach_client_permissions for each row execute function public.set_updated_at();
create trigger set_coach_availability_updated_at before update on public.coach_availability for each row execute function public.set_updated_at();
create trigger set_coach_sessions_updated_at before update on public.coach_sessions for each row execute function public.set_updated_at();
create trigger set_session_bookings_updated_at before update on public.session_bookings for each row execute function public.set_updated_at();
create trigger set_session_notes_updated_at before update on public.session_notes for each row execute function public.set_updated_at();
create trigger set_coach_reviews_updated_at before update on public.coach_reviews for each row execute function public.set_updated_at();

create or replace function public.prevent_client_booking_state_change()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.role() = 'authenticated' and (new.status <> old.status or new.payment_method <> old.payment_method) then
    raise exception 'booking state transitions are server-authorized' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger prevent_client_booking_state_change
before update on public.session_bookings
for each row execute function public.prevent_client_booking_state_change();

alter table public.coach_profiles enable row level security;
alter table public.coach_specialties enable row level security;
alter table public.coach_clients enable row level security;
alter table public.coach_client_permissions enable row level security;
alter table public.coach_availability enable row level security;
alter table public.coach_sessions enable row level security;
alter table public.session_bookings enable row level security;
alter table public.session_notes enable row level security;
alter table public.coach_reviews enable row level security;
alter table public.coach_profiles force row level security;
alter table public.coach_specialties force row level security;
alter table public.coach_clients force row level security;
alter table public.coach_client_permissions force row level security;
alter table public.coach_availability force row level security;
alter table public.coach_sessions force row level security;
alter table public.session_bookings force row level security;
alter table public.session_notes force row level security;
alter table public.coach_reviews force row level security;

create or replace function public.coach_can_access_client(p_coach_id uuid, p_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.coach_clients cc
    join public.coach_client_permissions ccp on ccp.coach_id = cc.coach_id and ccp.client_id = cc.client_id
    where cc.coach_id = p_coach_id
      and cc.client_id = p_client_id
      and cc.status = 'active'
  );
$$;

revoke all on function public.coach_can_access_client(uuid, uuid) from public;
revoke all on function public.coach_can_access_client(uuid, uuid) from anon;
grant execute on function public.coach_can_access_client(uuid, uuid) to authenticated;

create policy coach_profiles_select_verified_or_self on public.coach_profiles for select to authenticated using (verification_status = 'verified' or id = auth.uid());
create policy coach_profiles_insert_self on public.coach_profiles for insert to authenticated with check (id = auth.uid());
create policy coach_profiles_update_self on public.coach_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy coach_specialties_select_visible_coach on public.coach_specialties for select to authenticated using (exists (select 1 from public.coach_profiles cp where cp.id = coach_specialties.coach_id and (cp.verification_status = 'verified' or cp.id = auth.uid())));
create policy coach_specialties_all_self on public.coach_specialties for all to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());

create policy coach_clients_select_involved on public.coach_clients for select to authenticated using (auth.uid() in (coach_id, client_id));
create policy coach_client_permissions_select_involved on public.coach_client_permissions for select to authenticated using (auth.uid() in (coach_id, client_id));

create policy coach_availability_select_visible on public.coach_availability for select to authenticated using (is_active or coach_id = auth.uid());
create policy coach_availability_all_self on public.coach_availability for all to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());

create policy coach_sessions_select_involved_or_available on public.coach_sessions for select to authenticated using (coach_id = auth.uid() or client_id = auth.uid() or status = 'available');
create policy coach_sessions_insert_self on public.coach_sessions for insert to authenticated with check (coach_id = auth.uid());
create policy coach_sessions_update_self on public.coach_sessions for update to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());

create policy session_bookings_select_involved on public.session_bookings for select to authenticated using (client_id = auth.uid() or exists (select 1 from public.coach_sessions cs where cs.id = session_bookings.session_id and cs.coach_id = auth.uid()));

create policy session_notes_select_coach_or_shared_client on public.session_notes for select to authenticated using (coach_id = auth.uid() or (visibility = 'client_shared' and exists (select 1 from public.coach_sessions cs where cs.id = session_notes.session_id and cs.client_id = auth.uid() and public.coach_can_access_client(session_notes.coach_id, cs.client_id))));
create policy session_notes_all_coach on public.session_notes for all to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());

create policy coach_reviews_select_published_or_involved on public.coach_reviews for select to authenticated using (status = 'published' or auth.uid() in (coach_id, client_id));
create policy coach_reviews_insert_client on public.coach_reviews for insert to authenticated with check (client_id = auth.uid() and public.coach_can_access_client(coach_id, client_id));
create policy coach_reviews_update_client on public.coach_reviews for update to authenticated using (client_id = auth.uid()) with check (client_id = auth.uid());

-- Coach permission overlays on Batch 1 client data. Each domain requires its explicit permission bit.
create policy goals_select_granted_coach on public.goals for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = goals.user_id and cc.status = 'active' and ccp.goals));
create policy goal_targets_select_granted_coach on public.goal_targets for select to authenticated using (exists (select 1 from public.goals g join public.coach_client_permissions ccp on ccp.client_id = g.user_id join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where g.id = goal_targets.goal_id and ccp.coach_id = auth.uid() and cc.status = 'active' and ccp.goals));
create policy goal_milestones_select_granted_coach on public.goal_milestones for select to authenticated using (exists (select 1 from public.goals g join public.coach_client_permissions ccp on ccp.client_id = g.user_id join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where g.id = goal_milestones.goal_id and ccp.coach_id = auth.uid() and cc.status = 'active' and ccp.goals));
create policy food_logs_select_granted_coach on public.food_logs for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = food_logs.user_id and cc.status = 'active' and ccp.nutrition));
create policy food_log_items_select_granted_coach on public.food_log_items for select to authenticated using (exists (select 1 from public.food_logs fl join public.coach_client_permissions ccp on ccp.client_id = fl.user_id join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where fl.id = food_log_items.food_log_id and ccp.coach_id = auth.uid() and cc.status = 'active' and ccp.nutrition));
create policy daily_nutrition_summaries_select_granted_coach on public.daily_nutrition_summaries for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = daily_nutrition_summaries.user_id and cc.status = 'active' and ccp.nutrition));
create policy weight_entries_select_granted_coach on public.weight_entries for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = weight_entries.user_id and cc.status = 'active' and ccp.weight));
create policy body_measurements_select_granted_coach on public.body_measurements for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = body_measurements.user_id and cc.status = 'active' and ccp.measurements));
create policy mood_entries_select_granted_coach on public.mood_entries for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = mood_entries.user_id and cc.status = 'active' and ccp.mood));
create policy activity_entries_select_granted_coach on public.activity_entries for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = activity_entries.user_id and cc.status = 'active' and ccp.activity));
create policy progress_photos_select_granted_coach on public.progress_photos for select to authenticated using (exists (select 1 from public.coach_client_permissions ccp join public.coach_clients cc on cc.coach_id = ccp.coach_id and cc.client_id = ccp.client_id where ccp.coach_id = auth.uid() and ccp.client_id = progress_photos.user_id and cc.status = 'active' and ccp.progress_photos));

grant select, insert, update, delete on public.coach_profiles, public.coach_specialties, public.coach_availability, public.coach_sessions, public.coach_reviews to authenticated;
grant select on public.coach_clients, public.coach_client_permissions, public.session_bookings to authenticated;
grant select, insert, update, delete on public.session_notes to authenticated;

create policy live_rooms_insert_coach_session_authorized on public.live_rooms for insert to authenticated
with check (room_type = 'coach_client' and host_id = auth.uid() and exists (select 1 from public.coach_sessions cs where cs.id = coach_session_id and cs.coach_id = auth.uid()));

create policy live_room_participants_insert_coach_session_involved on public.live_room_participants for insert to authenticated
with check (
  user_id = auth.uid()
  and role = 'listener'
  and speak_state = 'listener'
  and not public.is_room_banned(room_id)
  and exists (
    select 1
    from public.live_rooms lr
    join public.coach_sessions cs on cs.id = lr.coach_session_id
    where lr.id = room_id
      and lr.room_type = 'coach_client'
      and auth.uid() in (cs.coach_id, cs.client_id)
  )
);
