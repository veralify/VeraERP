-- Phase 1 Batch 1 progress domain. All progress media and metrics are SELF and private by default.

create table if not exists public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 0 and weight_kg < 1000),
  measured_at timestamptz not null default now(),
  source text not null default 'manual',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  measurement_type public.measurement_type not null,
  value numeric not null check (value >= 0),
  unit text not null,
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mood_score integer not null check (mood_score between 1 and 10),
  energy_score integer check (energy_score is null or energy_score between 1 and 10),
  stress_score integer check (stress_score is null or stress_score between 1 and 10),
  notes text,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null,
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  calories_burned numeric check (calories_burned is null or calories_burned >= 0),
  steps integer check (steps is null or steps >= 0),
  source text not null default 'manual',
  started_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  captured_at timestamptz not null default now(),
  visibility public.privacy_visibility not null default 'private',
  caption text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.progress_videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  duration_seconds integer not null check (duration_seconds > 0),
  captured_at timestamptz not null default now(),
  visibility public.privacy_visibility not null default 'private',
  caption text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.progress_milestones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  type text not null,
  title text not null,
  description text,
  achieved_at timestamptz not null default now(),
  constraint progress_milestones_goal_user_fk foreign key (goal_id, user_id) references public.goals(id, user_id) on delete set null (goal_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_weight_entries_user_measured_at on public.weight_entries(user_id, measured_at desc);
create index if not exists idx_body_measurements_user_measured_at on public.body_measurements(user_id, measured_at desc);
create index if not exists idx_mood_entries_user_recorded_at on public.mood_entries(user_id, recorded_at desc);
create index if not exists idx_activity_entries_user_started_at on public.activity_entries(user_id, started_at desc);
create index if not exists idx_progress_photos_user_captured_at on public.progress_photos(user_id, captured_at desc);
create index if not exists idx_progress_videos_user_captured_at on public.progress_videos(user_id, captured_at desc);
create index if not exists idx_progress_milestones_user_achieved_at on public.progress_milestones(user_id, achieved_at desc);
create index if not exists idx_progress_milestones_goal_id on public.progress_milestones(goal_id);

create trigger set_weight_entries_updated_at before update on public.weight_entries for each row execute function public.set_updated_at();
create trigger set_body_measurements_updated_at before update on public.body_measurements for each row execute function public.set_updated_at();
create trigger set_mood_entries_updated_at before update on public.mood_entries for each row execute function public.set_updated_at();
create trigger set_activity_entries_updated_at before update on public.activity_entries for each row execute function public.set_updated_at();
create trigger set_progress_photos_updated_at before update on public.progress_photos for each row execute function public.set_updated_at();
create trigger set_progress_videos_updated_at before update on public.progress_videos for each row execute function public.set_updated_at();
create trigger set_progress_milestones_updated_at before update on public.progress_milestones for each row execute function public.set_updated_at();

alter table public.weight_entries enable row level security;
alter table public.body_measurements enable row level security;
alter table public.mood_entries enable row level security;
alter table public.activity_entries enable row level security;
alter table public.progress_photos enable row level security;
alter table public.progress_videos enable row level security;
alter table public.progress_milestones enable row level security;

alter table public.weight_entries force row level security;
alter table public.body_measurements force row level security;
alter table public.mood_entries force row level security;
alter table public.activity_entries force row level security;
alter table public.progress_photos force row level security;
alter table public.progress_videos force row level security;
alter table public.progress_milestones force row level security;

create policy weight_entries_all_own on public.weight_entries for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy body_measurements_all_own on public.body_measurements for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy mood_entries_all_own on public.mood_entries for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy activity_entries_all_own on public.activity_entries for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy progress_photos_all_own on public.progress_photos for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy progress_videos_all_own on public.progress_videos for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy progress_milestones_all_own on public.progress_milestones for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on public.weight_entries, public.body_measurements, public.mood_entries, public.activity_entries, public.progress_photos, public.progress_videos, public.progress_milestones to authenticated;
