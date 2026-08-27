-- Phase 1 Batch 3 moderation domain. Platform-admin checks use server-controlled JWT app_metadata.role.

create type public.report_status as enum ('pending', 'reviewing', 'resolved', 'dismissed');

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  description text,
  status public.report_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  action text not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_reports_reporter_created on public.reports(reporter_id, created_at desc);
create index if not exists idx_reports_status_created on public.reports(status, created_at desc);
create index if not exists idx_reports_target on public.reports(target_type, target_id);
create index if not exists idx_moderation_actions_moderator_created on public.moderation_actions(moderator_id, created_at desc);
create index if not exists idx_moderation_actions_target on public.moderation_actions(target_type, target_id);

create trigger set_reports_updated_at before update on public.reports for each row execute function public.set_updated_at();
create trigger set_moderation_actions_updated_at before update on public.moderation_actions for each row execute function public.set_updated_at();

alter table public.reports enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.reports force row level security;
alter table public.moderation_actions force row level security;

revoke all on function public.is_platform_admin() from anon;

create policy reports_insert_self on public.reports for insert to authenticated with check (reporter_id = auth.uid() and status = 'pending' and resolved_at is null);
create policy reports_select_admin on public.reports for select to authenticated using (public.is_platform_admin());
create policy reports_update_admin on public.reports for update to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy moderation_actions_all_admin on public.moderation_actions for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

grant select, insert, update on public.reports to authenticated;
grant select, insert, update, delete on public.moderation_actions to authenticated;
