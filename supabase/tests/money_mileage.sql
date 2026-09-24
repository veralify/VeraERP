begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '98000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'mileage-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '98000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'mileage-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('98000000-0000-0000-0000-000000000001', 'mileage-owner@example.test', 'mileage_owner'),
  ('98000000-0000-0000-0000-000000000002', 'mileage-other@example.test', 'mileage_other')
on conflict (id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000001', true);

select lives_ok($$select public.money_log_mileage_trip(
    p_trip_date := '2026-09-18', p_distance := 42, p_unit := 'mi', p_rate_per_unit := 0.45, p_amount := 18.90,
    p_currency := 'gbp', p_origin := 'Leeds', p_destination := 'York', p_purpose := 'Client visit',
    p_id := '99000000-0000-0000-0000-000000000001')$$,
  'owner can log a trip');

select is((select transaction_id is not null from public.money_mileage_trips where id = '99000000-0000-0000-0000-000000000001'), true, 'the trip links its expense');
select results_eq(
  $$select t.amount, t.currency, t.source::text, t.direction::text, t.category, t.scope::text, t.merchant
      from public.money_transactions t
      join public.money_mileage_trips m on m.transaction_id = t.id
     where m.id = '99000000-0000-0000-0000-000000000001'$$,
  $$values (18.90::numeric, 'GBP', 'mileage', 'expense', 'transport', 'business', 'Mileage: Leeds – York')$$,
  'the expense carries the amount, currency, source and scope');

select lives_ok($$select public.money_log_mileage_trip(p_trip_date := '2026-09-19', p_distance := 10, p_unit := 'km', p_rate_per_unit := 0.3, p_purpose := 'Supplies', p_scope := 'personal')$$,
  'amount defaults to distance × rate');
select is((select amount from public.money_transactions where merchant = 'Mileage: Supplies'), 3.00::numeric, 'default amount is 10 × 0.30');
select is((select scope::text from public.money_mileage_trips where purpose = 'Supplies'), 'personal', 'scope is kept on the trip');

select throws_ok($$select public.money_log_mileage_trip(p_trip_date := '2026-09-19', p_distance := 10, p_unit := 'km', p_rate_per_unit := 0.3, p_amount := -1)$$,
  '22023', null, 'a negative amount is refused');
select throws_ok($$select public.money_log_mileage_trip(p_trip_date := '2026-09-19', p_distance := 0, p_unit := 'km', p_rate_per_unit := 0.3)$$,
  '23514', null, 'a zero distance is refused and nothing is saved');
select is((select count(*)::int from public.money_transactions where source = 'mileage'), 2, 'the refused trip left no orphan expense');

select is(public.money_delete_mileage_trip('99000000-0000-0000-0000-000000000001'), true, 'owner can delete a trip');
select is((select count(*)::int from public.money_transactions t join public.money_mileage_trips m on m.transaction_id = t.id
            where m.id = '99000000-0000-0000-0000-000000000001' and t.deleted_at is not null and m.deleted_at is not null), 1,
  'deleting a trip soft-deletes its expense too');

create temporary table supplies_trip on commit drop as select id from public.money_mileage_trips where purpose = 'Supplies';
select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000002', true);
select is(public.money_delete_mileage_trip((select id from supplies_trip)), false,
  'another user cannot see or delete the trip');
reset role;

select * from finish();
rollback;
