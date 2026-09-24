begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'phase0-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'phase0-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('95000000-0000-0000-0000-000000000001', 'phase0-owner@example.test', 'phase0_owner'),
  ('95000000-0000-0000-0000-000000000002', 'phase0-other@example.test', 'phase0_other')
on conflict (id) do nothing;

-- Default categories
select is(
  (select count(*)::int from public.money_categories where user_id = '95000000-0000-0000-0000-000000000001'),
  18, 'a new profile starts with the eighteen default categories'
);
select is(
  (select array_agg(key order by sort_order) from public.money_categories where user_id = '95000000-0000-0000-0000-000000000001'),
  array['groceries', 'eating_out', 'transport', 'fuel', 'housing', 'utilities', 'shopping', 'health', 'entertainment',
        'travel', 'subscriptions', 'office_supplies', 'software', 'professional_services', 'education',
        'gifts_donations', 'fees_charges', 'other'],
  'in the contract''s order'
);
select is(public.money_seed_default_categories('95000000-0000-0000-0000-000000000001'), 0, 'seeding again adds nothing');

update public.money_categories set deleted_at = now()
 where user_id = '95000000-0000-0000-0000-000000000002' and key = 'fuel';
select is(public.money_seed_default_categories('95000000-0000-0000-0000-000000000002'), 0, 'a category the user deleted is not put back');

set local role authenticated;
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.money_seed_default_categories('95000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'a client cannot seed another account'
);
select throws_ok(
  $$select public.account_delete_vault_secrets('95000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'a client cannot delete Vault secrets'
);
reset role;

-- Account deletion: accounting tokens in Vault, then the cascade.
insert into vault.secrets (id, name, secret) values
  ('96000000-0000-0000-0000-000000000001', 'phase0-owner-xero', 'owner-token'),
  ('96000000-0000-0000-0000-000000000002', 'phase0-other-xero', 'other-token');
insert into public.accounting_connections (user_id, provider, external_company_id, token_secret_id) values
  ('95000000-0000-0000-0000-000000000001', 'xero', 'tenant-owner', '96000000-0000-0000-0000-000000000001'),
  ('95000000-0000-0000-0000-000000000002', 'xero', 'tenant-other', '96000000-0000-0000-0000-000000000002');
insert into public.money_transactions (user_id, transaction_date, merchant, amount, direction)
values ('95000000-0000-0000-0000-000000000001', current_date, 'Esselunga', 12.50, 'expense');

select is(public.account_delete_vault_secrets('95000000-0000-0000-0000-000000000001'), 1, 'the owner''s token secret is deleted');
select is(
  (select count(*)::int from vault.secrets where id = '96000000-0000-0000-0000-000000000002'),
  1, 'another account''s token secret is untouched'
);

delete from auth.users where id = '95000000-0000-0000-0000-000000000001';
select is(
  (select count(*)::int from public.money_transactions where user_id = '95000000-0000-0000-0000-000000000001'),
  0, 'deleting the auth user removes the money rows by cascade'
);
select is(
  (select count(*)::int from public.accounting_connections where user_id = '95000000-0000-0000-0000-000000000001'),
  0, 'and the accounting connections'
);

select * from finish();
rollback;
