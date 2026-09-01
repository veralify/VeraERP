begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'worker-claim@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;
insert into public.profiles (id, email, username)
values ('81000000-0000-0000-0000-000000000001', 'worker-claim@example.test', 'worker_claim')
on conflict (id) do nothing;
insert into public.notifications (id, user_id, type, title, body)
values ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'test', 'Test', 'Body')
on conflict (id) do nothing;
insert into public.notification_jobs (id, notification_id, user_id, provider, next_attempt_at)
values ('83000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'web', now() - interval '1 minute')
on conflict (id) do nothing;
insert into public.notification_jobs (id, notification_id, user_id, provider, status, next_attempt_at)
values ('83000000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'web', 'processing', now() - interval '1 minute')
on conflict (id) do nothing;

select is((select status::text from public.notification_jobs where id = '83000000-0000-0000-0000-000000000001'), 'pending', 'notification_jobs default to pending');
select is((select count(*)::int from public.claim_notification_jobs(10)), 1, 'claim function claims one pending job');
select is((select status::text from public.notification_jobs where id = '83000000-0000-0000-0000-000000000001'), 'processing', 'claimed job is processing');
select is((select count(*)::int from public.claim_notification_jobs(10)), 0, 'claim function is idempotent for already-processing jobs');
select is((select status::text from public.notification_jobs where id = '83000000-0000-0000-0000-000000000002'), 'processing', 'pre-processing job remains processing');
select isnt(has_function_privilege('anon', 'public.claim_notification_jobs(integer)', 'execute'), true, 'claim function execute revoked from anon');
select isnt(has_function_privilege('authenticated', 'public.claim_notification_jobs(integer)', 'execute'), true, 'claim function execute revoked from authenticated');
select has_function('public', 'claim_notification_jobs', array['integer'], 'claim function exists');

select * from finish();
rollback;
