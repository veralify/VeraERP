begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '95000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'scan-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values ('95000000-0000-0000-0000-000000000001', 'scan-owner@example.test', 'scan_owner')
on conflict (id) do nothing;

-- The gateway runs as the service role.
set local role service_role;

select is(
  public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 2),
  date_trunc('month', timezone('utc', now()))::date,
  'the first claim is counted against the current month'
);
select isnt(public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 2), null, 'the second claim fits the allowance of two');
select is(public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 2), null, 'the third claim is refused');
select is((select scans from public.money_receipt_usage where user_id = '95000000-0000-0000-0000-000000000001'), 2, 'a refused claim does not count');

-- A model outage gives the scan back and still records what it cost.
select lives_ok($$select public.money_settle_receipt_scan('95000000-0000-0000-0000-000000000001', date_trunc('month', timezone('utc', now()))::date, false, 0.004)$$, 'settling a failed read');
select is((select scans from public.money_receipt_usage where user_id = '95000000-0000-0000-0000-000000000001'), 1, 'a failed read returns its scan');
select is((select cost_usd from public.money_receipt_usage where user_id = '95000000-0000-0000-0000-000000000001'), 0.004::numeric, 'its cost is still recorded');
select isnt(public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 2), null, 'the returned scan can be used again');
select is(public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 0), null, 'a limit of zero refuses every scan');

-- The client can read its usage but never reset it.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000001', true);
select throws_ok($$select public.money_claim_receipt_scan('95000000-0000-0000-0000-000000000001', 1000)$$, '42501', null, 'the client cannot claim scans itself');

select * from finish();
rollback;
