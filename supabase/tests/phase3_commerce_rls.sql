begin;

create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'commerce-active@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'commerce-expired@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'commerce-trial@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'commerce-coach@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('71000000-0000-0000-0000-000000000001', 'commerce-active@example.test', 'commerce_active'),
  ('71000000-0000-0000-0000-000000000002', 'commerce-expired@example.test', 'commerce_expired'),
  ('71000000-0000-0000-0000-000000000003', 'commerce-trial@example.test', 'commerce_trial'),
  ('71000000-0000-0000-0000-000000000004', 'commerce-coach@example.test', 'commerce_coach')
on conflict (id) do nothing;

insert into public.subscriptions (id, user_id, stripe_customer_id, stripe_subscription_id, plan_id, status, current_period_start, current_period_end, cancel_at_period_end)
select '72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'cus_active_test', 'sub_active_test', id, 'active', now() - interval '1 day', now() + interval '30 days', false from public.plans where code = 'VERALIFY_PRO'
on conflict (id) do update set status = excluded.status, current_period_end = excluded.current_period_end;
insert into public.subscriptions (id, user_id, stripe_customer_id, stripe_subscription_id, plan_id, status, current_period_start, current_period_end, cancel_at_period_end)
select '72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 'cus_expired_test', 'sub_expired_test', id, 'active', now() - interval '30 days', now() - interval '1 day', false from public.plans where code = 'VERALIFY_PRO'
on conflict (id) do update set status = excluded.status, current_period_end = excluded.current_period_end;
insert into public.subscriptions (id, user_id, stripe_customer_id, stripe_subscription_id, plan_id, status, current_period_start, current_period_end, cancel_at_period_end)
select '72000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000003', 'cus_trial_test', 'sub_trial_test', id, 'trialing', now(), now() + interval '3 days', false from public.plans where code = 'VERALIFY_PRO'
on conflict (id) do update set status = excluded.status, current_period_end = excluded.current_period_end;
insert into public.subscriptions (id, user_id, stripe_customer_id, stripe_subscription_id, plan_id, status, current_period_start, current_period_end, cancel_at_period_end)
select '72000000-0000-0000-0000-000000000004', '71000000-0000-0000-0000-000000000004', 'cus_coach_test', 'sub_coach_test', id, 'active', now(), now() + interval '30 days', false from public.plans where code = 'VERALIFY_COACH'
on conflict (id) do update set status = excluded.status, current_period_end = excluded.current_period_end;

select lives_ok($$select count(*) from public.project_user_entitlements('71000000-0000-0000-0000-000000000001')$$, 'projection runs for active subscription');
select is((select count(*)::int from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000001' and source = 'stripe' and active), 11, 'active Pro subscription projects all 11 Pro keys');
select ok(exists (select 1 from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000001' and lookup_key = 'ai_food_logging' and active), 'active Pro includes ai_food_logging');
select ok(exists (select 1 from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000001' and lookup_key = 'coach_discovery' and active), 'active Pro includes coach_discovery');
select isnt(has_function_privilege('authenticated', 'public.project_user_entitlements(uuid)', 'execute'), true, 'projection execute revoked from authenticated');
select isnt(has_function_privilege('anon', 'public.project_user_entitlements(uuid)', 'execute'), true, 'projection execute revoked from anon');

select lives_ok($$select count(*) from public.project_user_entitlements('71000000-0000-0000-0000-000000000002')$$, 'projection runs for expired subscription');
select is((select count(*)::int from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000002' and source = 'stripe' and active), 0, 'expired subscription projects no active keys');

select lives_ok($$select count(*) from public.project_user_entitlements('71000000-0000-0000-0000-000000000003')$$, 'projection runs for trial subscription');
select is((select count(*)::int from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000003' and source = 'stripe' and active), 12, 'trial subscription projects Pro keys plus trial flag');
select ok(exists (select 1 from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000003' and lookup_key = 'trial_active' and active), 'trial flag projected');

select lives_ok($$select count(*) from public.project_user_entitlements('71000000-0000-0000-0000-000000000004')$$, 'projection runs for coach subscription');
select is((select count(*)::int from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000004' and source = 'stripe' and active), 17, 'VERALIFY_COACH projects Pro plus 6 coach keys');
select ok(exists (select 1 from public.user_entitlements where user_id = '71000000-0000-0000-0000-000000000004' and lookup_key = 'coach_dashboard' and active), 'coach subscription includes coach_dashboard');

select * from finish();
rollback;
