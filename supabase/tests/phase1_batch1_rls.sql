begin;

create extension if not exists pgtap with schema extensions;
select plan(37);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'batch1-a@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'batch1-b@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('10000000-0000-0000-0000-000000000001', 'batch1-a@example.test', 'batch1_a'),
  ('10000000-0000-0000-0000-000000000002', 'batch1-b@example.test', 'batch1_b')
on conflict (id) do nothing;

insert into public.food_logs (id, user_id, logged_at, source, notes)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', now(), 'manual', 'A log'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', now(), 'manual', 'B log')
on conflict (id) do nothing;

insert into public.food_log_items (id, food_log_id, name, quantity, unit, grams, calories, protein_g, carbs_g, fat_g, fiber_g, ai_estimated)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'A item', 1, 'serving', 100, 100, 10, 10, 2, 1, false),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'B item', 1, 'serving', 100, 100, 10, 10, 2, 1, false)
on conflict (id) do nothing;

insert into public.weight_entries (id, user_id, weight_kg, measured_at, source)
values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 80, now(), 'manual'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 70, now(), 'manual')
on conflict (id) do nothing;

select ok(relrowsecurity, 'RLS enabled: profiles') from pg_class where oid = 'public.profiles'::regclass;
select ok(relrowsecurity, 'RLS enabled: profile_preferences') from pg_class where oid = 'public.profile_preferences'::regclass;
select ok(relrowsecurity, 'RLS enabled: profile_privacy') from pg_class where oid = 'public.profile_privacy'::regclass;
select ok(relrowsecurity, 'RLS enabled: user_devices') from pg_class where oid = 'public.user_devices'::regclass;
select ok(relrowsecurity, 'RLS enabled: user_blocks') from pg_class where oid = 'public.user_blocks'::regclass;
select ok(relrowsecurity, 'RLS enabled: goals') from pg_class where oid = 'public.goals'::regclass;
select ok(relrowsecurity, 'RLS enabled: goal_targets') from pg_class where oid = 'public.goal_targets'::regclass;
select ok(relrowsecurity, 'RLS enabled: goal_milestones') from pg_class where oid = 'public.goal_milestones'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_sources') from pg_class where oid = 'public.food_sources'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_external_mappings') from pg_class where oid = 'public.food_external_mappings'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_nutrition_versions') from pg_class where oid = 'public.food_nutrition_versions'::regclass;
select ok(relrowsecurity, 'RLS enabled: foods') from pg_class where oid = 'public.foods'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_servings') from pg_class where oid = 'public.food_servings'::regclass;
select ok(relrowsecurity, 'RLS enabled: meal_groups') from pg_class where oid = 'public.meal_groups'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_logs') from pg_class where oid = 'public.food_logs'::regclass;
select ok(relrowsecurity, 'RLS enabled: food_log_items') from pg_class where oid = 'public.food_log_items'::regclass;
select ok(relrowsecurity, 'RLS enabled: daily_nutrition_summaries') from pg_class where oid = 'public.daily_nutrition_summaries'::regclass;
select ok(relrowsecurity, 'RLS enabled: weight_entries') from pg_class where oid = 'public.weight_entries'::regclass;
select ok(relrowsecurity, 'RLS enabled: body_measurements') from pg_class where oid = 'public.body_measurements'::regclass;
select ok(relrowsecurity, 'RLS enabled: mood_entries') from pg_class where oid = 'public.mood_entries'::regclass;
select ok(relrowsecurity, 'RLS enabled: activity_entries') from pg_class where oid = 'public.activity_entries'::regclass;
select ok(relrowsecurity, 'RLS enabled: progress_photos') from pg_class where oid = 'public.progress_photos'::regclass;
select ok(relrowsecurity, 'RLS enabled: progress_videos') from pg_class where oid = 'public.progress_videos'::regclass;
select ok(relrowsecurity, 'RLS enabled: progress_milestones') from pg_class where oid = 'public.progress_milestones'::regclass;
select ok(relrowsecurity, 'RLS enabled: audit_logs') from pg_class where oid = 'public.audit_logs'::regclass;
select ok(relrowsecurity, 'RLS enabled: idempotency_keys') from pg_class where oid = 'public.idempotency_keys'::regclass;
select ok(relrowsecurity, 'RLS enabled: data_deletion_requests') from pg_class where oid = 'public.data_deletion_requests'::regclass;
select ok(relrowsecurity, 'RLS enabled: data_exports') from pg_class where oid = 'public.data_exports'::regclass;
select ok(relrowsecurity, 'RLS enabled: consent_records') from pg_class where oid = 'public.consent_records'::regclass;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*)::int from public.food_logs where id = '20000000-0000-0000-0000-000000000002'), 0, 'SELF: user A cannot read user B food log');
select is((select count(*)::int from public.weight_entries where id = '40000000-0000-0000-0000-000000000002'), 0, 'SELF: user A cannot read user B weight entry');
select is((select count(*)::int from public.food_log_items where id = '30000000-0000-0000-0000-000000000002'), 0, 'PARENT-OWNED: user A cannot read item under user B log');
select throws_ok($$insert into public.food_log_items (food_log_id, name, quantity, unit, grams, calories) values ('20000000-0000-0000-0000-000000000002', 'bad', 1, 'serving', 1, 1)$$, '42501', null, 'PARENT-OWNED: user A cannot insert item under user B log');
select ok((select count(*) > 0 from public.foods), 'foods PUBLIC read works for authenticated');
select throws_ok($$insert into public.foods (source, external_id, name, serving_size, serving_unit, calories) values ('usda', 'auth-write-denied', 'Denied', 100, 'g', 1)$$, '42501', null, 'foods write denied to authenticated');
reset role;

select isnt(has_function_privilege('anon', 'public.owns_food_log(uuid)', 'execute'), true, 'owns_food_log execute revoked from anon');
select isnt(has_function_privilege('anon', 'public.is_platform_admin()', 'execute'), true, 'is_platform_admin execute revoked from anon');

select * from finish();
rollback;
