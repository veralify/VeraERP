alter table if exists public.vera_users
  add column if not exists role text not null default 'user';

update public.vera_users
set role = 'user'
where role is null;

create index if not exists idx_vera_users_role
  on public.vera_users(role);
