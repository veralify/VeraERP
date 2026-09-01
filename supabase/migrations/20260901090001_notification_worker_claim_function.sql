alter table public.notification_jobs alter column status set default 'pending';

alter table public.notification_jobs drop constraint if exists notification_jobs_terminal_check;
alter table public.notification_jobs add constraint notification_jobs_terminal_check check (
  (status = 'sent' and sent_at is not null)
  or (status = 'dead_letter' and dead_letter_at is not null)
  or status in ('pending', 'queued', 'processing', 'failed')
);

create or replace function public.claim_notification_jobs(p_limit integer default 50)
returns setof public.notification_jobs
language sql
security definer
set search_path = public, pg_temp
as $$
  with candidates as (
    select id
    from public.notification_jobs
    where status in ('pending', 'failed')
      and next_attempt_at <= now()
      and attempts < max_attempts
    order by next_attempt_at asc, scheduled_at asc, created_at asc
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ), claimed as (
    update public.notification_jobs nj
    set status = 'processing',
        updated_at = now()
    from candidates c
    where nj.id = c.id
    returning nj.*
  )
  select * from claimed;
$$;

revoke all on function public.claim_notification_jobs(integer) from public;
revoke all on function public.claim_notification_jobs(integer) from anon;
revoke all on function public.claim_notification_jobs(integer) from authenticated;
grant execute on function public.claim_notification_jobs(integer) to service_role;
