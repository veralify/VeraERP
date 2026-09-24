begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '97000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'inbound-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '97000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'inbound-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('97000000-0000-0000-0000-000000000001', 'inbound-owner@example.test', 'inbound_owner'),
  ('97000000-0000-0000-0000-000000000002', 'inbound-other@example.test', 'inbound_other')
on conflict (id) do nothing;

set local role authenticated;

select throws_ok($$select * from public.money_inbound_address()$$, '42501', null, 'signed out: no address');

select set_config('request.jwt.claim.sub', '97000000-0000-0000-0000-000000000001', true);
create temporary table first_token on commit drop as select token from public.money_inbound_address();
select ok((select token ~ '^[0-9a-f]{24}$' from first_token), 'first call creates a 24-hex-digit token');
select is((select token from public.money_inbound_address()), (select token from first_token), 'asking again returns the same address');
select is((select count(*)::int from public.money_inbound_addresses), 1, 'the owner can read their row');

create temporary table rotated on commit drop as select token from public.money_inbound_address(true);
select isnt((select token from rotated), (select token from first_token), 'rotating issues a new token');
select is((select token from public.money_inbound_addresses), (select token from rotated), 'the old token is gone');

select is(public.money_set_inbound_address_enabled(false), false, 'forwarding can be paused');
select is((select enabled from public.money_inbound_address()), false, 'paused state is kept, with the address');
select throws_ok($$update public.money_inbound_addresses set token = 'chosen'$$, '42501', null, 'the token cannot be chosen by the client');

select set_config('request.jwt.claim.sub', '97000000-0000-0000-0000-000000000002', true);
select isnt((select token from public.money_inbound_address()), (select token from rotated), 'another user gets their own address');
select is((select count(*)::int from public.money_inbound_addresses), 1, 'and sees only their own row');
reset role;

select * from finish();
rollback;
