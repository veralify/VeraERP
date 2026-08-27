-- Phase 1 Batch 3 notifications domain.
-- notification_jobs is the durable outbox. pg_cron should invoke notification-worker every minute to claim rows with FOR UPDATE SKIP LOCKED using idx_notification_jobs_claim_batch.

create type public.notification_provider as enum ('apns', 'email', 'web');
create type public.notification_job_status as enum ('queued', 'processing', 'sent', 'failed', 'dead_letter');

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  social boolean not null default true,
  chat boolean not null default true,
  live boolean not null default true,
  coaching boolean not null default true,
  nutrition boolean not null default true,
  goals boolean not null default true,
  marketing boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider public.notification_provider not null,
  status public.notification_job_status not null default 'queued',
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 5 check (max_attempts > 0),
  scheduled_at timestamptz not null default now(),
  next_attempt_at timestamptz not null default now(),
  sent_at timestamptz,
  failed_at timestamptz,
  last_error text,
  idempotency_key_id uuid references public.idempotency_keys(id) on delete restrict,
  dead_letter_at timestamptz,
  dead_letter_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_jobs_terminal_check check (
    (status = 'sent' and sent_at is not null)
    or (status = 'dead_letter' and dead_letter_at is not null)
    or status in ('queued', 'processing', 'failed')
  )
);

create index if not exists idx_notifications_user_created_at on public.notifications(user_id, created_at desc);
create index if not exists idx_notification_preferences_user_id on public.notification_preferences(user_id);
create index if not exists idx_notification_jobs_user_created on public.notification_jobs(user_id, created_at desc);
create index if not exists idx_notification_jobs_notification_id on public.notification_jobs(notification_id);
create index if not exists idx_notification_jobs_idempotency_key_id on public.notification_jobs(idempotency_key_id);
create index if not exists idx_notification_jobs_claim_batch on public.notification_jobs(status, next_attempt_at, scheduled_at, attempts) where status in ('queued', 'failed');
create index if not exists idx_notification_jobs_dead_letter on public.notification_jobs(dead_letter_at) where status = 'dead_letter';

create trigger set_notifications_updated_at before update on public.notifications for each row execute function public.set_updated_at();
create trigger set_notification_preferences_updated_at before update on public.notification_preferences for each row execute function public.set_updated_at();
create trigger set_notification_jobs_updated_at before update on public.notification_jobs for each row execute function public.set_updated_at();

alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_jobs enable row level security;
alter table public.notifications force row level security;
alter table public.notification_preferences force row level security;
alter table public.notification_jobs force row level security;

create policy notifications_select_own on public.notifications for select to authenticated using (auth.uid() = user_id);
create policy notifications_update_read_own on public.notifications for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy notification_preferences_all_own on public.notification_preferences for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

revoke select, insert, update, delete on public.notification_jobs from anon, authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;
