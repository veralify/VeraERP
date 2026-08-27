-- Phase 1 Batch 1 security and compliance infrastructure.
-- audit_logs and idempotency_keys are server-only; data export/deletion requests are self create/read only.

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  ip_hash text,
  request_metadata jsonb,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  scope public.idempotency_scope not null,
  request_hash text not null,
  response jsonb,
  status public.idempotency_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint idempotency_keys_expires_check check (expires_at > created_at)
);

create table if not exists public.data_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  status public.deletion_request_status not null default 'pending',
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default (now() + interval '30 days'),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint data_deletion_completed_check check ((status = 'completed') = (completed_at is not null) or status <> 'completed')
);

create table if not exists public.data_exports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.data_export_status not null default 'pending',
  artifact_path text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  consent_type public.consent_type not null,
  version text not null,
  granted boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_actor_created_at on public.audit_logs(actor_id, created_at desc);
create index if not exists idx_audit_logs_target on public.audit_logs(target_type, target_id, created_at desc);
create index if not exists idx_idempotency_keys_scope_status_expires on public.idempotency_keys(scope, status, expires_at);
create index if not exists idx_data_deletion_requests_user_requested on public.data_deletion_requests(user_id, requested_at desc);
create index if not exists idx_data_deletion_requests_status_scheduled on public.data_deletion_requests(status, scheduled_for);
create index if not exists idx_data_exports_user_requested on public.data_exports(user_id, requested_at desc);
create index if not exists idx_data_exports_status_expires on public.data_exports(status, expires_at);
create index if not exists idx_consent_records_user_type_created on public.consent_records(user_id, consent_type, created_at desc);

create trigger set_audit_logs_updated_at before update on public.audit_logs for each row execute function public.set_updated_at();
create trigger set_idempotency_keys_updated_at before update on public.idempotency_keys for each row execute function public.set_updated_at();
create trigger set_data_deletion_requests_updated_at before update on public.data_deletion_requests for each row execute function public.set_updated_at();
create trigger set_data_exports_updated_at before update on public.data_exports for each row execute function public.set_updated_at();
create trigger set_consent_records_updated_at before update on public.consent_records for each row execute function public.set_updated_at();

alter table public.audit_logs enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.data_deletion_requests enable row level security;
alter table public.data_exports enable row level security;
alter table public.consent_records enable row level security;

alter table public.audit_logs force row level security;
alter table public.idempotency_keys force row level security;
alter table public.data_deletion_requests force row level security;
alter table public.data_exports force row level security;
alter table public.consent_records force row level security;

create policy data_deletion_requests_select_own on public.data_deletion_requests for select to authenticated using (auth.uid() = user_id);
create policy data_deletion_requests_insert_own on public.data_deletion_requests for insert to authenticated with check (auth.uid() = user_id and status = 'pending' and completed_at is null);
create policy data_exports_select_own on public.data_exports for select to authenticated using (auth.uid() = user_id);
create policy data_exports_insert_own on public.data_exports for insert to authenticated with check (auth.uid() = user_id and status = 'pending' and artifact_path is null and completed_at is null and expires_at is null);
create policy consent_records_select_own on public.consent_records for select to authenticated using (auth.uid() = user_id);
create policy consent_records_insert_own on public.consent_records for insert to authenticated with check (auth.uid() = user_id);

grant select, insert on public.data_deletion_requests, public.data_exports, public.consent_records to authenticated;
revoke select, insert, update, delete on public.audit_logs, public.idempotency_keys from anon, authenticated;
revoke update, delete on public.data_deletion_requests, public.data_exports, public.consent_records from anon, authenticated;
