begin;

create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'receipts-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'receipts-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('91000000-0000-0000-0000-000000000001', 'receipts-owner@example.test', 'receipts_owner'),
  ('91000000-0000-0000-0000-000000000002', 'receipts-other@example.test', 'receipts_other')
on conflict (id) do nothing;

-- Service-role fixtures: a receipt the gateway has read, and a connection.
insert into public.money_receipts (id, user_id, image_paths, status, extraction, model)
values ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001',
        array['91000000-0000-0000-0000-000000000001/92000000-0000-0000-0000-000000000001/1.jpg'],
        'extracted', '{"total": {"value": "12.50"}}', 'test-model');
insert into public.accounting_connections (id, user_id, provider, external_company_id, company_name, token_secret_id)
values ('93000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'xero', 'tenant-1', 'Test Ltd', gen_random_uuid());

-- Owner
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);

select is((select count(*)::int from public.money_receipts), 1, 'owner sees their receipt');
select throws_ok($$update public.money_receipts set extraction = '{"total": {"value": "0"}}' where id = '92000000-0000-0000-0000-000000000001'$$, '42501', null, 'owner cannot overwrite the AI extraction');
select throws_ok($$update public.money_receipts set status = 'confirmed' where id = '92000000-0000-0000-0000-000000000001'$$, '42501', null, 'owner cannot set receipt status directly');
select throws_ok($$select token_secret_id from public.accounting_connections$$, '42501', null, 'token reference is hidden from the owner');
select is((select company_name from public.accounting_connections), 'Test Ltd', 'owner can read their connection');
select throws_ok($$insert into public.accounting_connections (user_id, provider, external_company_id) values ('91000000-0000-0000-0000-000000000001', 'quickbooks', 'x')$$, '42501', null, 'owner cannot create a connection directly');
select lives_ok($$update public.accounting_connections set auto_sync = false$$, 'owner can pause auto-sync');
select throws_ok($$select * from public.accounting_oauth_states$$, '42501', null, 'oauth handshakes are service-role only');

-- Confirming: saving a transaction that links the receipt marks it confirmed.
select lives_ok($$insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, receipt_id, source)
  values ('94000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', current_date, 'Esselunga', 12.50, 'expense', '92000000-0000-0000-0000-000000000001', 'receipt')$$,
  'owner can save a transaction from their receipt');
select is((select status::text from public.money_receipts where id = '92000000-0000-0000-0000-000000000001'), 'confirmed', 'the receipt is marked confirmed and linked');

-- Sync cursor advances on every write.
insert into public.money_budgets (user_id, category_key, monthly_limit) values ('91000000-0000-0000-0000-000000000001', 'groceries', 400);
create temporary table cursor_before on commit drop as select sync_seq from public.money_budgets where category_key = 'groceries';
update public.money_budgets set monthly_limit = 450 where category_key = 'groceries';
select cmp_ok((select sync_seq from public.money_budgets where category_key = 'groceries'), '>', (select sync_seq from cursor_before), 'an update moves the row past the previous sync cursor');
select is((select count(*)::int from public.money_budgets), 1, 'owner sees their budget');
select lives_ok($$update public.money_receipts set deleted_at = now() where id = '92000000-0000-0000-0000-000000000001'$$, 'owner can soft-delete a receipt');

-- Storage: own folder only.
select lives_ok($$insert into storage.objects (bucket_id, name) values ('receipts', '91000000-0000-0000-0000-000000000001/new/1.jpg')$$, 'owner can upload into their own folder');
select throws_ok($$insert into storage.objects (bucket_id, name) values ('receipts', '91000000-0000-0000-0000-000000000002/new/1.jpg')$$, '42501', null, 'owner cannot upload into another user''s folder');

-- Someone else
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000002', true);
select is((select count(*)::int from public.money_receipts), 0, 'another user cannot see the receipt');
select is((select count(*)::int from public.money_budgets), 0, 'another user cannot see the budget');
select is((select count(*)::int from public.accounting_connections), 0, 'another user cannot see the connection');
reset role;

select * from finish();
rollback;
