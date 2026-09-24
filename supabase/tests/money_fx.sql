begin;

create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'fx-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'fx-gbp@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('95000000-0000-0000-0000-000000000001', 'fx-owner@example.test', 'fx_owner'),
  ('95000000-0000-0000-0000-000000000002', 'fx-gbp@example.test', 'fx_gbp')
on conflict (id) do nothing;

-- Two ECB publications: Thursday and Friday. Nothing on the weekend.
insert into public.fx_rates (rate_date, base, quote, rate) values
  ('2026-09-17', 'EUR', 'USD', 1.1600), ('2026-09-17', 'EUR', 'GBP', 0.8600), ('2026-09-17', 'EUR', 'JPY', 170.00),
  ('2026-09-18', 'EUR', 'USD', 1.1700), ('2026-09-18', 'EUR', 'GBP', 0.8500);

-- Rates
select is(public.money_fx_rate('EUR', 'EUR', '2026-09-18'), 1::numeric, 'same currency is 1 without a lookup');
select is(public.money_fx_rate('EUR', 'USD', '2026-09-18'), 1.1700::numeric, 'EUR to a quote is the published rate');
select is(public.money_fx_rate('eur', 'usd', '2026-09-18'), 1.1700::numeric, 'codes are case-insensitive');
select is(public.money_fx_rate('EUR', 'USD', '2026-09-20'), 1.1700::numeric, 'a Sunday uses the nearest earlier publication (Friday)');
select is(public.money_fx_rate('EUR', 'USD', '2026-09-17'), 1.1600::numeric, 'a later rate is never used for an earlier date');
select is(round(public.money_fx_rate('USD', 'EUR', '2026-09-18'), 6), round(1 / 1.17, 6), 'quote to EUR is the inverse');
select is(round(public.money_fx_rate('USD', 'GBP', '2026-09-18'), 6), round(0.85 / 1.17, 6), 'a cross rate goes through EUR');
select is(round(public.money_fx_rate('JPY', 'USD', '2026-09-18'), 6), round(1.16 / 170, 6), 'both legs of a cross rate come from the same day');
select is(public.money_fx_rate('EUR', 'USD', '2026-09-10'), null, 'no rate before the history starts');
select is(public.money_fx_rate('EUR', 'USD', '2026-10-01'), null, 'a rate more than a week old is treated as missing');
select is(public.money_fx_rate('EUR', 'XAU', '2026-09-18'), null, 'an unpublished currency has no rate');

-- Conversion
select is(public.money_convert(100, 'USD', 'EUR', '2026-09-18'), 85.47::numeric, 'money_convert rounds to cents');
select is(public.money_convert(100, 'EUR', 'EUR', '2026-01-01'), 100::numeric, 'same-currency conversion needs no rate');
select is(public.money_convert(100, 'USD', 'EUR', '2020-01-01'), null, 'missing rate converts to null, not a guess');

-- home_amount, as the owner (home currency unset → EUR).
set local role authenticated;
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000001', true);

insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, currency)
values
  ('96000000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000001', '2026-09-18', 'Bar', 12.50, 'expense', 'EUR'),
  ('96000000-0000-0000-0000-000000000002', '95000000-0000-0000-0000-000000000001', '2026-09-19', 'Diner', 117.00, 'expense', 'USD'),
  ('96000000-0000-0000-0000-000000000003', '95000000-0000-0000-0000-000000000001', '2026-09-25', 'Shop', 10.00, 'expense', 'CHF');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000001'), 12.50::numeric, 'same currency: home_amount is the amount');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000002'), 100.00::numeric, 'foreign currency is converted at the nearest earlier rate');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000003'), null, 'no rate: home_amount stays null');

update public.money_transactions set home_amount = 1 where id = '96000000-0000-0000-0000-000000000002';
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000002'), 100.00::numeric, 'a client cannot write its own home_amount');

-- Switching home currency re-prices the user's transactions.
insert into public.money_settings (user_id, key, value) values ('95000000-0000-0000-0000-000000000001', 'homeCurrency', '"gbp"');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000001'), 10.63::numeric, 'EUR row re-priced into GBP (12.50 × 0.85)');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000002'), 85.00::numeric, 'USD row re-priced into GBP through EUR');
select throws_ok($$select public.money_backfill_home_amounts()$$, '42501', null, 'clients cannot run the backfill');
select throws_ok($$insert into public.fx_rates (rate_date, base, quote, rate) values ('2026-09-25', 'EUR', 'CHF', 0.94)$$, '42501', null, 'clients cannot write rates');
reset role;

-- A later sync brings the missing rate; the backfill fills only rows that
-- now convert.
insert into public.fx_rates (rate_date, base, quote, rate) values ('2026-09-25', 'EUR', 'CHF', 0.9400), ('2026-09-25', 'EUR', 'GBP', 0.8400);
select is(public.money_backfill_home_amounts(), 1, 'backfill touches only the row that now has a rate');
select is((select home_amount from public.money_transactions where id = '96000000-0000-0000-0000-000000000003'), 8.94::numeric, 'CHF row filled in GBP (10 / 0.94 × 0.84)');

select * from finish();
rollback;
