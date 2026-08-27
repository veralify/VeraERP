-- Phase 1 Batch 1 goals domain. Child table RLS derives ownership through goals.

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  description text,
  target_value numeric,
  starting_value numeric,
  unit text,
  start_date date,
  target_date date,
  status public.goal_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint goals_target_date_check check (target_date is null or start_date is null or target_date >= start_date),
  unique (id, user_id)
);

create table if not exists public.goal_targets (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  metric text not null,
  target_value numeric not null,
  unit text,
  period public.goal_period not null default 'overall',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.goal_milestones (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  title text not null,
  target_value numeric,
  achieved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_goals_user_id_status on public.goals(user_id, status);
create index if not exists idx_goals_user_id_target_date on public.goals(user_id, target_date);
create index if not exists idx_goal_targets_goal_id on public.goal_targets(goal_id);
create index if not exists idx_goal_milestones_goal_id on public.goal_milestones(goal_id);

create trigger set_goals_updated_at before update on public.goals for each row execute function public.set_updated_at();
create trigger set_goal_targets_updated_at before update on public.goal_targets for each row execute function public.set_updated_at();
create trigger set_goal_milestones_updated_at before update on public.goal_milestones for each row execute function public.set_updated_at();

alter table public.goals enable row level security;
alter table public.goal_targets enable row level security;
alter table public.goal_milestones enable row level security;
alter table public.goals force row level security;
alter table public.goal_targets force row level security;
alter table public.goal_milestones force row level security;

create policy goals_all_own on public.goals for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy goal_targets_all_parent_owned on public.goal_targets for all to authenticated
using (exists (select 1 from public.goals g where g.id = goal_targets.goal_id and g.user_id = auth.uid()))
with check (exists (select 1 from public.goals g where g.id = goal_targets.goal_id and g.user_id = auth.uid()));
create policy goal_milestones_all_parent_owned on public.goal_milestones for all to authenticated
using (exists (select 1 from public.goals g where g.id = goal_milestones.goal_id and g.user_id = auth.uid()))
with check (exists (select 1 from public.goals g where g.id = goal_milestones.goal_id and g.user_id = auth.uid()));

grant select, insert, update, delete on public.goals, public.goal_targets, public.goal_milestones to authenticated;
