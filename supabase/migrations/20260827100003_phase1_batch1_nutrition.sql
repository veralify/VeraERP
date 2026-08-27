-- Phase 1 Batch 1 nutrition domain. Provenance-first food cache with immutable logged snapshots.
-- Ambiguity resolved: food_log_items adds food_nutrition_version_id, sugar_g, and sodium_mg so
-- historical entries can reference the source version and retain complete macro/common micro snapshots.

create table if not exists public.food_sources (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code in ('usda', 'openfoodfacts', 'verified_internal', 'user_submitted', 'ai_estimated')),
  name text not null,
  priority integer not null check (priority >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  external_id text not null,
  name text not null,
  brand text,
  serving_size numeric not null check (serving_size > 0),
  serving_unit text not null,
  calories numeric not null check (calories >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  fiber_g numeric not null default 0 check (fiber_g >= 0),
  sugar_g numeric not null default 0 check (sugar_g >= 0),
  sodium_mg numeric not null default 0 check (sodium_mg >= 0),
  barcode text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source, external_id)
);

create table if not exists public.food_external_mappings (
  id uuid primary key default gen_random_uuid(),
  food_id uuid not null references public.foods(id) on delete cascade,
  food_source_id uuid not null references public.food_sources(id) on delete restrict,
  external_id text not null,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (food_source_id, external_id)
);

create table if not exists public.food_nutrition_versions (
  id uuid primary key default gen_random_uuid(),
  food_id uuid not null references public.foods(id) on delete cascade,
  version integer not null check (version > 0),
  nutrition jsonb not null,
  change_reason text not null check (change_reason in ('provider_sync', 'user_correction', 'admin_fix', 'ai_estimate')),
  changed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (food_id, version),
  unique (id, food_id)
);

create table if not exists public.food_servings (
  id uuid primary key default gen_random_uuid(),
  food_id uuid not null references public.foods(id) on delete cascade,
  label text not null,
  grams numeric not null check (grams > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (food_id, label)
);

create table if not exists public.meal_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  meal_type public.meal_type not null default 'other',
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  meal_group_id uuid references public.meal_groups(id) on delete set null,
  logged_at timestamptz not null default now(),
  source public.food_log_source not null default 'manual',
  photo_path text,
  notes text,
  constraint food_logs_meal_group_user_fk foreign key (meal_group_id, user_id) references public.meal_groups(id, user_id) on delete set null (meal_group_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_log_items (
  id uuid primary key default gen_random_uuid(),
  food_log_id uuid not null references public.food_logs(id) on delete cascade,
  food_id uuid references public.foods(id) on delete set null,
  food_nutrition_version_id uuid references public.food_nutrition_versions(id) on delete set null,
  name text not null,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  grams numeric check (grams is null or grams > 0),
  calories numeric not null check (calories >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  fiber_g numeric not null default 0 check (fiber_g >= 0),
  sugar_g numeric not null default 0 check (sugar_g >= 0),
  sodium_mg numeric not null default 0 check (sodium_mg >= 0),
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  ai_estimated boolean not null default false,
  constraint food_log_items_version_requires_food_check check (food_nutrition_version_id is null or food_id is not null),
  constraint food_log_items_version_food_fk foreign key (food_nutrition_version_id, food_id) references public.food_nutrition_versions(id, food_id) on delete set null (food_nutrition_version_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_nutrition_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  calories numeric not null default 0 check (calories >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  fiber_g numeric not null default 0 check (fiber_g >= 0),
  water_ml numeric not null default 0 check (water_ml >= 0),
  meal_count integer not null default 0 check (meal_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

create index if not exists idx_food_external_mappings_food_id on public.food_external_mappings(food_id);
create index if not exists idx_food_external_mappings_source_external on public.food_external_mappings(food_source_id, external_id);
create index if not exists idx_food_nutrition_versions_food_id_version on public.food_nutrition_versions(food_id, version desc);
create index if not exists idx_food_nutrition_versions_changed_by on public.food_nutrition_versions(changed_by);
create index if not exists idx_foods_name on public.foods using gin (to_tsvector('simple', name));
create index if not exists idx_foods_barcode on public.foods(barcode) where barcode is not null;
create index if not exists idx_food_servings_food_id on public.food_servings(food_id);
create index if not exists idx_meal_groups_user_logged_at on public.meal_groups(user_id, logged_at desc);
create index if not exists idx_food_logs_user_id_logged_at on public.food_logs(user_id, logged_at desc);
create index if not exists idx_food_logs_meal_group_id on public.food_logs(meal_group_id);
create index if not exists idx_food_log_items_food_log_id on public.food_log_items(food_log_id);
create index if not exists idx_food_log_items_food_id on public.food_log_items(food_id);
create index if not exists idx_food_log_items_nutrition_version_id on public.food_log_items(food_nutrition_version_id);
create index if not exists idx_daily_nutrition_summaries_user_date on public.daily_nutrition_summaries(user_id, date desc);

create trigger set_food_sources_updated_at before update on public.food_sources for each row execute function public.set_updated_at();
create trigger set_foods_updated_at before update on public.foods for each row execute function public.set_updated_at();
create trigger set_food_external_mappings_updated_at before update on public.food_external_mappings for each row execute function public.set_updated_at();
create trigger set_food_nutrition_versions_updated_at before update on public.food_nutrition_versions for each row execute function public.set_updated_at();
create trigger set_food_servings_updated_at before update on public.food_servings for each row execute function public.set_updated_at();
create trigger set_meal_groups_updated_at before update on public.meal_groups for each row execute function public.set_updated_at();
create trigger set_food_logs_updated_at before update on public.food_logs for each row execute function public.set_updated_at();
create trigger set_food_log_items_updated_at before update on public.food_log_items for each row execute function public.set_updated_at();
create trigger set_daily_nutrition_summaries_updated_at before update on public.daily_nutrition_summaries for each row execute function public.set_updated_at();

create or replace function public.owns_food_log(p_food_log_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.food_logs fl
    where fl.id = p_food_log_id
      and fl.user_id = auth.uid()
  );
$$;

revoke all on function public.owns_food_log(uuid) from public;
revoke all on function public.owns_food_log(uuid) from anon;
grant execute on function public.owns_food_log(uuid) to authenticated;

alter table public.food_sources enable row level security;
alter table public.food_external_mappings enable row level security;
alter table public.food_nutrition_versions enable row level security;
alter table public.foods enable row level security;
alter table public.food_servings enable row level security;
alter table public.meal_groups enable row level security;
alter table public.food_logs enable row level security;
alter table public.food_log_items enable row level security;
alter table public.daily_nutrition_summaries enable row level security;

alter table public.food_sources force row level security;
alter table public.food_external_mappings force row level security;
alter table public.food_nutrition_versions force row level security;
alter table public.foods force row level security;
alter table public.food_servings force row level security;
alter table public.meal_groups force row level security;
alter table public.food_logs force row level security;
alter table public.food_log_items force row level security;
alter table public.daily_nutrition_summaries force row level security;

create policy food_sources_select_public on public.food_sources for select to anon, authenticated using (true);
create policy foods_select_public on public.foods for select to anon, authenticated using (true);
create policy food_servings_select_public on public.food_servings for select to anon, authenticated using (true);
create policy food_external_mappings_select_public on public.food_external_mappings for select to anon, authenticated using (true);
create policy food_nutrition_versions_select_public on public.food_nutrition_versions for select to anon, authenticated using (true);

create policy meal_groups_all_own on public.meal_groups for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy food_logs_all_own on public.food_logs for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy food_log_items_all_parent_owned on public.food_log_items for all to authenticated using (public.owns_food_log(food_log_id)) with check (public.owns_food_log(food_log_id));
create policy daily_nutrition_summaries_all_own on public.daily_nutrition_summaries for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select on public.food_sources, public.food_external_mappings, public.food_nutrition_versions, public.foods, public.food_servings to anon, authenticated;
revoke insert, update, delete on public.food_sources, public.food_external_mappings, public.food_nutrition_versions, public.foods, public.food_servings from anon, authenticated;
grant select, insert, update, delete on public.meal_groups, public.food_logs, public.food_log_items, public.daily_nutrition_summaries to authenticated;
