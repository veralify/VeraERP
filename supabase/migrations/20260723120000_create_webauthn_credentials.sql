-- Passkeys (WebAuthn) credential storage for Supabase-native accounts.
-- Each row is one registered authenticator bound to an auth.users id.

create table if not exists public.webauthn_credentials (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  credential_id text not null unique,          -- base64url credential ID
  public_key text not null,                    -- base64url COSE public key
  counter bigint not null default 0,
  transports text[] not null default '{}',
  device_label text,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

create index if not exists idx_webauthn_credentials_user_id
  on public.webauthn_credentials(user_id);

-- Short-lived WebAuthn challenges (register/authenticate ceremonies).
create table if not exists public.webauthn_challenges (
  id uuid default gen_random_uuid() primary key,
  email text not null,
  challenge text not null,
  purpose text not null check (purpose in ('registration', 'authentication')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes')
);

create index if not exists idx_webauthn_challenges_email
  on public.webauthn_challenges(email, purpose);

-- Lock everything down: only the service role (Edge Functions) touches these.
alter table public.webauthn_credentials enable row level security;
alter table public.webauthn_challenges enable row level security;

-- Users may read (but not write) their own credential metadata.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'webauthn_credentials'
      and policyname = 'webauthn_credentials_select_own'
  ) then
    create policy webauthn_credentials_select_own
      on public.webauthn_credentials
      for select
      using (auth.uid() = user_id);
  end if;
end $$;
