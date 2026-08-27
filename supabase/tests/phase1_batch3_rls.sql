begin;

create extension if not exists pgtap with schema extensions;
select plan(56);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'batch3-coach@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'batch3-client@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'batch3-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'batch3-admin@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('60000000-0000-0000-0000-000000000001', 'batch3-coach@example.test', 'batch3_coach'),
  ('60000000-0000-0000-0000-000000000002', 'batch3-client@example.test', 'batch3_client'),
  ('60000000-0000-0000-0000-000000000003', 'batch3-other@example.test', 'batch3_other'),
  ('60000000-0000-0000-0000-000000000004', 'batch3-admin@example.test', 'batch3_admin')
on conflict (id) do nothing;

insert into public.coach_profiles (id, headline, verification_status, hourly_rate, currency)
values ('60000000-0000-0000-0000-000000000001', 'Coach', 'verified', 5000, 'USD')
on conflict (id) do nothing;
insert into public.coach_clients (coach_id, client_id, status)
values
  ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'active'),
  ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', 'active')
on conflict (coach_id, client_id) do nothing;
insert into public.coach_client_permissions (coach_id, client_id, nutrition, weight, measurements, goals, progress_photos, activity, mood)
values
  ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', false, true, false, true, false, false, false),
  ('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', false, false, false, true, false, false, false)
on conflict (coach_id, client_id) do update set weight = excluded.weight, nutrition = excluded.nutrition;

insert into public.weight_entries (id, user_id, weight_kg, source)
values
  ('61000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 80, 'manual'),
  ('61000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', 70, 'manual')
on conflict (id) do nothing;
insert into public.food_logs (id, user_id, source)
values ('62000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'manual')
on conflict (id) do nothing;
insert into public.goals (id, user_id, type, title)
values ('63000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'weight', 'Client goal')
on conflict (id) do nothing;

insert into public.coach_sessions (id, coach_id, client_id, title, scheduled_at, duration_minutes, status)
values ('64000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'Session', now() + interval '1 day', 60, 'booked')
on conflict (id) do nothing;
insert into public.session_bookings (id, session_id, client_id, status, payment_method)
values ('65000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'confirmed', 'stripe')
on conflict (id) do nothing;

insert into public.plans (id, code, name, is_active)
values ('66000000-0000-0000-0000-000000000001', 'pro_test', 'Pro Test', true)
on conflict (id) do nothing;
insert into public.user_entitlements (id, user_id, lookup_key, source, active)
values
  ('67000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'VERALIFY_PRO', 'stripe', true),
  ('67000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', 'VERALIFY_PRO', 'apple', true)
on conflict (id) do nothing;
insert into public.iap_transactions (id, user_id, apple_original_transaction_id, apple_transaction_id, product_id, plan_id, status, purchased_at, environment, raw_payload)
values ('68000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'orig-batch3', 'txn-batch3', 'com.veralify.pro.monthly', '66000000-0000-0000-0000-000000000001', 'active', now(), 'sandbox', '{}')
on conflict (id) do nothing;

insert into public.ai_requests (id, user_id, task, request_id, status, fallback_used)
values ('69000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'nutrition_summary', 'req-batch3-client', 'completed', false)
on conflict (id) do nothing;
insert into public.ai_model_runs (id, ai_request_id, model, provider, model_policy_version, prompt_version, tool_schema_version, safety_policy_version, success, structured_output_valid)
values ('6a000000-0000-0000-0000-000000000001', '69000000-0000-0000-0000-000000000001', 'test-model', 'test-provider', 'policy-v1', 'prompt-v1', 'tools-v1', 'safety-v1', true, true)
on conflict (id) do nothing;

insert into public.notifications (id, user_id, type, title, body)
values
  ('6b000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'test', 'Hello', 'Client notification'),
  ('6b000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', 'test', 'Hello', 'Other notification')
on conflict (id) do nothing;
insert into public.notification_jobs (id, notification_id, user_id, provider, status)
values ('6c000000-0000-0000-0000-000000000001', '6b000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'apns', 'queued')
on conflict (id) do nothing;

select ok(relrowsecurity, 'RLS enabled: coach_profiles') from pg_class where oid = 'public.coach_profiles'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_specialties') from pg_class where oid = 'public.coach_specialties'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_clients') from pg_class where oid = 'public.coach_clients'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_client_permissions') from pg_class where oid = 'public.coach_client_permissions'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_availability') from pg_class where oid = 'public.coach_availability'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_sessions') from pg_class where oid = 'public.coach_sessions'::regclass;
select ok(relrowsecurity, 'RLS enabled: session_bookings') from pg_class where oid = 'public.session_bookings'::regclass;
select ok(relrowsecurity, 'RLS enabled: session_notes') from pg_class where oid = 'public.session_notes'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_reviews') from pg_class where oid = 'public.coach_reviews'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_conversations') from pg_class where oid = 'public.ai_conversations'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_messages') from pg_class where oid = 'public.ai_messages'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_requests') from pg_class where oid = 'public.ai_requests'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_model_runs') from pg_class where oid = 'public.ai_model_runs'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_tool_calls') from pg_class where oid = 'public.ai_tool_calls'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_food_estimates') from pg_class where oid = 'public.ai_food_estimates'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_insights') from pg_class where oid = 'public.ai_insights'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_recommendations') from pg_class where oid = 'public.ai_recommendations'::regclass;
select ok(relrowsecurity, 'RLS enabled: ai_feedback') from pg_class where oid = 'public.ai_feedback'::regclass;
select ok(relrowsecurity, 'RLS enabled: plans') from pg_class where oid = 'public.plans'::regclass;
select ok(relrowsecurity, 'RLS enabled: billing_products') from pg_class where oid = 'public.billing_products'::regclass;
select ok(relrowsecurity, 'RLS enabled: plan_entitlements') from pg_class where oid = 'public.plan_entitlements'::regclass;
select ok(relrowsecurity, 'RLS enabled: subscriptions') from pg_class where oid = 'public.subscriptions'::regclass;
select ok(relrowsecurity, 'RLS enabled: subscription_events') from pg_class where oid = 'public.subscription_events'::regclass;
select ok(relrowsecurity, 'RLS enabled: iap_transactions') from pg_class where oid = 'public.iap_transactions'::regclass;
select ok(relrowsecurity, 'RLS enabled: user_entitlements') from pg_class where oid = 'public.user_entitlements'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_stripe_accounts') from pg_class where oid = 'public.coach_stripe_accounts'::regclass;
select ok(relrowsecurity, 'RLS enabled: session_payment_intents') from pg_class where oid = 'public.session_payment_intents'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_transactions') from pg_class where oid = 'public.coach_transactions'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_payouts') from pg_class where oid = 'public.coach_payouts'::regclass;
select ok(relrowsecurity, 'RLS enabled: coach_platform_fees') from pg_class where oid = 'public.coach_platform_fees'::regclass;
select ok(relrowsecurity, 'RLS enabled: refunds') from pg_class where oid = 'public.refunds'::regclass;
select ok(relrowsecurity, 'RLS enabled: notifications') from pg_class where oid = 'public.notifications'::regclass;
select ok(relrowsecurity, 'RLS enabled: notification_preferences') from pg_class where oid = 'public.notification_preferences'::regclass;
select ok(relrowsecurity, 'RLS enabled: notification_jobs') from pg_class where oid = 'public.notification_jobs'::regclass;
select ok(relrowsecurity, 'RLS enabled: reports') from pg_class where oid = 'public.reports'::regclass;
select ok(relrowsecurity, 'RLS enabled: moderation_actions') from pg_class where oid = 'public.moderation_actions'::regclass;

set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);
select is((select count(*)::int from public.weight_entries where id = '61000000-0000-0000-0000-000000000001'), 1, 'granted coach can read client weight');
select is((select count(*)::int from public.weight_entries where id = '61000000-0000-0000-0000-000000000002'), 0, 'coach cannot read non-granted client weight');
select is((select count(*)::int from public.food_logs where id = '62000000-0000-0000-0000-000000000001'), 0, 'coach cannot read client nutrition without nutrition grant');
select is((select count(*)::int from public.goals where id = '63000000-0000-0000-0000-000000000001'), 1, 'coach can read client goals when goals grant is true');
select ok(public.coach_can_access_client('60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002'), 'coach_can_access_client true for active relationship');

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000002', true);
select is((select count(*)::int from public.session_bookings where id = '65000000-0000-0000-0000-000000000001'), 1, 'client sees own booking');
select is((select count(*)::int from public.user_entitlements where id = '67000000-0000-0000-0000-000000000001'), 1, 'user reads own entitlement');
select is((select count(*)::int from public.user_entitlements where id = '67000000-0000-0000-0000-000000000002'), 0, 'user cannot read another entitlement');
select throws_ok($$select count(*) from public.iap_transactions$$, '42501', null, 'user cannot read iap transaction rows');
select is((select count(*)::int from public.ai_model_runs where id = '6a000000-0000-0000-0000-000000000001'), 1, 'user reads ai_model_runs through own ai_request');
select is((select count(*)::int from public.notifications where id = '6b000000-0000-0000-0000-000000000001'), 1, 'user reads own notification');
select is((select count(*)::int from public.notifications where id = '6b000000-0000-0000-0000-000000000002'), 0, 'user cannot read another notification');
select throws_ok($$select count(*) from public.notification_jobs$$, '42501', null, 'user cannot read notification jobs');
select lives_ok($$insert into public.reports (id, reporter_id, target_type, target_id, reason) values ('6d000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'post', '52000000-0000-0000-0000-000000000002', 'spam')$$, 'user can create own report');
select is((select count(*)::int from public.reports where id = '6d000000-0000-0000-0000-000000000001'), 0, 'non-admin cannot read reports');

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000003', true);
select is((select count(*)::int from public.ai_model_runs where id = '6a000000-0000-0000-0000-000000000001'), 0, 'other user cannot read ai_model_runs for another request');
select is((select count(*)::int from public.session_bookings where id = '65000000-0000-0000-0000-000000000001'), 0, 'other user cannot read booking');

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"60000000-0000-0000-0000-000000000004","role":"authenticated","app_metadata":{"role":"platform_admin"}}', true);
select is((select count(*)::int from public.reports where id = '6d000000-0000-0000-0000-000000000001'), 1, 'platform admin can read reports');
select lives_ok($$insert into public.moderation_actions (moderator_id, target_type, target_id, action, reason) values ('60000000-0000-0000-0000-000000000004', 'post', '52000000-0000-0000-0000-000000000002', 'remove', 'spam')$$, 'platform admin can write moderation action');
reset role;

select isnt(has_function_privilege('anon', 'public.coach_can_access_client(uuid, uuid)', 'execute'), true, 'coach_can_access_client execute revoked from anon');

select * from finish();
rollback;
