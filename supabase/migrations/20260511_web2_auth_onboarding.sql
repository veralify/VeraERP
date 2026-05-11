alter table if exists public.vera_users
  add column if not exists account_identifier text,
  add column if not exists privy_user_id text,
  add column if not exists social_provider text,
  add column if not exists social_user_id text,
  add column if not exists email text,
  add column if not exists phone text,
  add column if not exists display_name text;

create unique index if not exists idx_vera_users_account_identifier
  on public.vera_users(account_identifier)
  where account_identifier is not null;

create unique index if not exists idx_vera_users_privy_user_id
  on public.vera_users(privy_user_id)
  where privy_user_id is not null;

create unique index if not exists idx_vera_users_social_identity
  on public.vera_users(social_provider, social_user_id)
  where social_provider is not null and social_user_id is not null;
