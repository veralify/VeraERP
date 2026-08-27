-- Phase 1 Batch 2 live rooms domain. Agora privileges must derive from server-side room state.
-- Ambiguity resolved: room_type controls visibility: public rooms are discoverable, group rooms require group membership, coach_client rooms require participation.

create type public.live_room_type as enum ('public', 'group', 'coach_client');
create type public.live_room_status as enum ('scheduled', 'live', 'ended', 'cancelled');
create type public.live_room_role as enum ('host', 'moderator', 'speaker', 'listener');
create type public.live_room_speak_state as enum ('listener', 'request_to_speak', 'approved_speaker', 'speaking');
create type public.room_moderation_action as enum ('mute', 'remove', 'ban', 'approve_speaker', 'revoke_speaker', 'dismiss_hand');

create table if not exists public.live_rooms (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade,
  host_id uuid not null references public.profiles(id) on delete cascade,
  coach_session_id uuid,
  title text not null,
  description text,
  room_type public.live_room_type not null default 'public',
  status public.live_room_status not null default 'scheduled',
  scheduled_at timestamptz not null,
  started_at timestamptz,
  ended_at timestamptz,
  max_participants integer check (max_participants is null or max_participants > 0),
  agora_channel text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint live_rooms_type_target_check check (
    (room_type = 'public' and group_id is null and coach_session_id is null)
    or (room_type = 'group' and group_id is not null and coach_session_id is null)
    or (room_type = 'coach_client' and group_id is null and coach_session_id is not null)
  ),
  constraint live_rooms_time_check check (ended_at is null or started_at is null or ended_at >= started_at)
);

create table if not exists public.live_room_hosts (
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.live_room_role not null default 'host' check (role in ('host', 'moderator')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.live_room_participants (
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  role public.live_room_role not null default 'listener',
  speak_state public.live_room_speak_state not null default 'listener',
  hand_raised_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id),
  constraint live_room_participants_role_state_check check (
    (role in ('host', 'moderator') and speak_state in ('approved_speaker', 'speaking'))
    or (role = 'speaker' and speak_state in ('approved_speaker', 'speaking'))
    or (role = 'listener' and speak_state in ('listener', 'request_to_speak'))
  )
);

create table if not exists public.room_banned_users (
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  banned_by uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id),
  constraint room_banned_users_not_self_check check (user_id <> banned_by)
);

create table if not exists public.room_moderation_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  moderator_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid not null references public.profiles(id) on delete cascade,
  action public.room_moderation_action not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.live_room_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_live_rooms_group_scheduled_at on public.live_rooms(group_id, scheduled_at);
create index if not exists idx_live_rooms_status_scheduled_at on public.live_rooms(status, scheduled_at);
create index if not exists idx_live_rooms_host_scheduled_at on public.live_rooms(host_id, scheduled_at desc);
create index if not exists idx_live_rooms_coach_session_id on public.live_rooms(coach_session_id) where coach_session_id is not null;
create index if not exists idx_live_room_hosts_user_id on public.live_room_hosts(user_id);
create index if not exists idx_live_room_participants_user_id on public.live_room_participants(user_id);
create index if not exists idx_live_room_participants_room_role on public.live_room_participants(room_id, role);
create index if not exists idx_room_banned_users_user_id on public.room_banned_users(user_id);
create index if not exists idx_room_moderation_events_room_created_at on public.room_moderation_events(room_id, created_at desc);
create index if not exists idx_room_moderation_events_target_user_id on public.room_moderation_events(target_user_id);
create index if not exists idx_live_room_events_room_created_at on public.live_room_events(room_id, created_at desc);
create index if not exists idx_live_room_events_user_id on public.live_room_events(user_id);

create trigger set_live_rooms_updated_at before update on public.live_rooms for each row execute function public.set_updated_at();
create trigger set_live_room_hosts_updated_at before update on public.live_room_hosts for each row execute function public.set_updated_at();
create trigger set_live_room_participants_updated_at before update on public.live_room_participants for each row execute function public.set_updated_at();
create trigger set_room_banned_users_updated_at before update on public.room_banned_users for each row execute function public.set_updated_at();
create trigger set_room_moderation_events_updated_at before update on public.room_moderation_events for each row execute function public.set_updated_at();
create trigger set_live_room_events_updated_at before update on public.live_room_events for each row execute function public.set_updated_at();

alter table public.live_rooms enable row level security;
alter table public.live_room_hosts enable row level security;
alter table public.live_room_participants enable row level security;
alter table public.room_banned_users enable row level security;
alter table public.room_moderation_events enable row level security;
alter table public.live_room_events enable row level security;
alter table public.live_rooms force row level security;
alter table public.live_room_hosts force row level security;
alter table public.live_room_participants force row level security;
alter table public.room_banned_users force row level security;
alter table public.room_moderation_events force row level security;
alter table public.live_room_events force row level security;

create or replace function public.is_room_banned(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.room_banned_users rbu
    where rbu.room_id = p_room_id
      and rbu.user_id = auth.uid()
  );
$$;

create or replace function public.is_room_participant(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.live_room_participants lrp
    where lrp.room_id = p_room_id
      and lrp.user_id = auth.uid()
      and lrp.left_at is null
  ) and not public.is_room_banned(p_room_id);
$$;

create or replace function public.is_room_moderator(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.live_room_participants lrp
    where lrp.room_id = p_room_id
      and lrp.user_id = auth.uid()
      and lrp.left_at is null
      and lrp.role in ('host', 'moderator')
  ) and not public.is_room_banned(p_room_id);
$$;

revoke all on function public.is_room_banned(uuid) from public;
revoke all on function public.is_room_banned(uuid) from anon;
grant execute on function public.is_room_banned(uuid) to authenticated;
revoke all on function public.is_room_participant(uuid) from public;
revoke all on function public.is_room_participant(uuid) from anon;
grant execute on function public.is_room_participant(uuid) to authenticated;
revoke all on function public.is_room_moderator(uuid) from public;
revoke all on function public.is_room_moderator(uuid) from anon;
grant execute on function public.is_room_moderator(uuid) to authenticated;

create policy live_rooms_select_visible on public.live_rooms for select to authenticated
using (
  not public.is_room_banned(id)
  and (
    room_type = 'public'
    or (room_type = 'group' and group_id is not null and public.is_group_member(group_id))
    or public.is_room_participant(id)
  )
);
create policy live_rooms_insert_authorized on public.live_rooms for insert to authenticated
with check (
  host_id = auth.uid()
  and (
    room_type = 'public'
    or (room_type = 'group' and group_id is not null and public.is_group_admin(group_id))
  )
);
create policy live_rooms_update_host_or_group_admin on public.live_rooms for update to authenticated
using (host_id = auth.uid() or public.is_room_moderator(id) or (group_id is not null and public.is_group_admin(group_id)))
with check (host_id = auth.uid() or public.is_room_moderator(id) or (group_id is not null and public.is_group_admin(group_id)));
create policy live_rooms_delete_host_or_group_admin on public.live_rooms for delete to authenticated
using (host_id = auth.uid() or (group_id is not null and public.is_group_admin(group_id)));

create policy live_room_hosts_select_visible_room on public.live_room_hosts for select to authenticated
using (exists (select 1 from public.live_rooms lr where lr.id = live_room_hosts.room_id and not public.is_room_banned(lr.id) and (lr.room_type = 'public' or (lr.room_type = 'group' and lr.group_id is not null and public.is_group_member(lr.group_id)) or public.is_room_participant(lr.id))));
create policy live_room_hosts_insert_room_host on public.live_room_hosts for insert to authenticated
with check (user_id = auth.uid() and role = 'host' and exists (select 1 from public.live_rooms lr where lr.id = room_id and lr.host_id = auth.uid()));
create policy live_room_hosts_all_moderator on public.live_room_hosts for all to authenticated
using (public.is_room_moderator(room_id)) with check (public.is_room_moderator(room_id));

create policy live_room_participants_select_visible_room on public.live_room_participants for select to authenticated
using (exists (select 1 from public.live_rooms lr where lr.id = live_room_participants.room_id and not public.is_room_banned(lr.id) and (lr.room_type = 'public' or (lr.room_type = 'group' and lr.group_id is not null and public.is_group_member(lr.group_id)) or public.is_room_participant(lr.id))));
create policy live_room_participants_insert_self_listener_or_host on public.live_room_participants for insert to authenticated
with check (
  user_id = auth.uid()
  and not public.is_room_banned(room_id)
  and exists (select 1 from public.live_rooms lr where lr.id = room_id and (lr.room_type = 'public' or (lr.room_type = 'group' and lr.group_id is not null and public.is_group_member(lr.group_id)) or lr.host_id = auth.uid()))
  and (
    (role = 'listener' and speak_state = 'listener')
    or (role = 'host' and speak_state in ('approved_speaker', 'speaking') and exists (select 1 from public.live_rooms lr where lr.id = room_id and lr.host_id = auth.uid()))
  )
);
create policy live_room_participants_update_moderator_other_users on public.live_room_participants for update to authenticated
using (user_id <> auth.uid() and public.is_room_moderator(room_id))
with check (user_id <> auth.uid() and public.is_room_moderator(room_id));
create policy live_room_participants_delete_moderator_or_self_leave on public.live_room_participants for delete to authenticated
using (user_id = auth.uid() or public.is_room_moderator(room_id));

create policy room_banned_users_select_self_or_moderator on public.room_banned_users for select to authenticated
using (user_id = auth.uid() or public.is_room_moderator(room_id));
create policy room_banned_users_insert_moderator on public.room_banned_users for insert to authenticated
with check (banned_by = auth.uid() and public.is_room_moderator(room_id));
create policy room_banned_users_delete_moderator on public.room_banned_users for delete to authenticated
using (public.is_room_moderator(room_id));

create policy room_moderation_events_select_involved on public.room_moderation_events for select to authenticated
using (target_user_id = auth.uid() or moderator_id = auth.uid() or public.is_room_moderator(room_id));
create policy room_moderation_events_insert_moderator on public.room_moderation_events for insert to authenticated
with check (moderator_id = auth.uid() and public.is_room_moderator(room_id));

revoke select, insert, update, delete on public.live_room_events from anon, authenticated;
grant select, insert, update, delete on public.live_rooms, public.live_room_hosts, public.live_room_participants, public.room_banned_users, public.room_moderation_events to authenticated;
