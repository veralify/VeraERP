-- Phase 1 Batch 2 communities domain.
-- Ambiguity resolved: group visibility is constrained to public/private. Moderators are treated as group admins for moderation policy purposes.

create type public.group_role as enum ('owner', 'admin', 'moderator', 'coach', 'member');
create type public.group_member_status as enum ('active', 'pending', 'blocked', 'removed');
create type public.group_visibility as enum ('public', 'private');
create type public.group_type as enum ('general', 'challenge', 'support', 'coaching');

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  avatar_path text,
  cover_path text,
  type public.group_type not null default 'general',
  visibility public.group_visibility not null default 'private',
  goal_type text,
  member_limit integer check (member_limit is null or member_limit > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groups_slug_format_check check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$')
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.group_role not null default 'member',
  status public.group_member_status not null default 'active',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.group_rules (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  rule_text text not null,
  position integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, position)
);

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  invited_user_id uuid references public.profiles(id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint group_invites_expires_check check (expires_at > created_at),
  constraint group_invites_accepted_check check (accepted_at is null or accepted_at <= now() + interval '1 minute')
);

create index if not exists idx_groups_owner_id on public.groups(owner_id);
create index if not exists idx_groups_visibility_active on public.groups(visibility, is_active);
create index if not exists idx_group_members_user_status on public.group_members(user_id, status);
create index if not exists idx_group_members_group_status_role on public.group_members(group_id, status, role);
create index if not exists idx_group_rules_group_position on public.group_rules(group_id, position);
create index if not exists idx_group_invites_group_id on public.group_invites(group_id);
create index if not exists idx_group_invites_invited_user_id on public.group_invites(invited_user_id);
create index if not exists idx_group_invites_expires_at on public.group_invites(expires_at);

create trigger set_groups_updated_at before update on public.groups for each row execute function public.set_updated_at();
create trigger set_group_members_updated_at before update on public.group_members for each row execute function public.set_updated_at();
create trigger set_group_rules_updated_at before update on public.group_rules for each row execute function public.set_updated_at();
create trigger set_group_invites_updated_at before update on public.group_invites for each row execute function public.set_updated_at();

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_rules enable row level security;
alter table public.group_invites enable row level security;
alter table public.groups force row level security;
alter table public.group_members force row level security;
alter table public.group_rules force row level security;
alter table public.group_invites force row level security;

create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'active'
  );
$$;

create or replace function public.is_group_admin(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'active'
      and gm.role in ('owner', 'admin', 'moderator')
  );
$$;

revoke all on function public.is_group_member(uuid) from public;
revoke all on function public.is_group_member(uuid) from anon;
grant execute on function public.is_group_member(uuid) to authenticated;
revoke all on function public.is_group_admin(uuid) from public;
revoke all on function public.is_group_admin(uuid) from anon;
grant execute on function public.is_group_admin(uuid) to authenticated;

create policy groups_select_visible on public.groups for select to anon, authenticated
using (is_active and (visibility = 'public' or public.is_group_member(id)));
create policy groups_insert_owner on public.groups for insert to authenticated
with check (owner_id = auth.uid());
create policy groups_update_admin on public.groups for update to authenticated
using (public.is_group_admin(id)) with check (public.is_group_admin(id));
create policy groups_delete_owner on public.groups for delete to authenticated
using (owner_id = auth.uid());

create policy group_members_select_member on public.group_members for select to authenticated
using (public.is_group_member(group_id));
create policy group_members_insert_initial_owner on public.group_members for insert to authenticated
with check (user_id = auth.uid() and role = 'owner' and status = 'active' and exists (select 1 from public.groups g where g.id = group_id and g.owner_id = auth.uid()));
create policy group_members_insert_public_self on public.group_members for insert to authenticated
with check (user_id = auth.uid() and role = 'member' and status = 'active' and exists (select 1 from public.groups g where g.id = group_id and g.visibility = 'public' and g.is_active));
create policy group_members_insert_admin on public.group_members for insert to authenticated
with check (public.is_group_admin(group_id));
create policy group_members_update_admin on public.group_members for update to authenticated
using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));
create policy group_members_delete_self_or_admin on public.group_members for delete to authenticated
using (user_id = auth.uid() or public.is_group_admin(group_id));

create policy group_rules_select_visible_group on public.group_rules for select to anon, authenticated
using (exists (select 1 from public.groups g where g.id = group_rules.group_id and g.is_active and (g.visibility = 'public' or public.is_group_member(g.id))));
create policy group_rules_all_admin on public.group_rules for all to authenticated
using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));

create policy group_invites_select_involved on public.group_invites for select to authenticated
using (invited_user_id = auth.uid() or invited_by = auth.uid() or public.is_group_admin(group_id));
create policy group_invites_insert_admin on public.group_invites for insert to authenticated
with check (invited_by = auth.uid() and public.is_group_admin(group_id));
create policy group_invites_update_invited_accept on public.group_invites for update to authenticated
using (invited_user_id = auth.uid() or public.is_group_admin(group_id))
with check (invited_user_id = auth.uid() or public.is_group_admin(group_id));
create policy group_invites_delete_admin on public.group_invites for delete to authenticated
using (public.is_group_admin(group_id));

grant select on public.groups, public.group_rules to anon, authenticated;
grant select, insert, update, delete on public.groups, public.group_members, public.group_rules, public.group_invites to authenticated;
