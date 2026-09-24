begin;

create extension if not exists pgtap with schema extensions;
select plan(57);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a3000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'acct-owner@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a3000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'acct-other@example.test', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles (id, email, username)
values
  ('a3000000-0000-0000-0000-000000000001', 'acct-owner@example.test', 'acct_owner'),
  ('a3000000-0000-0000-0000-000000000002', 'acct-other@example.test', 'acct_other')
on conflict (id) do nothing;

-- A single-company consent: stored in Vault, auto-sync on.
create temporary table saved_one on commit drop as
  select * from public.accounting_save_connections(
    'a3000000-0000-0000-0000-000000000001', 'xero',
    '{"access_token":"at-1","refresh_token":"rt-1","expires_at":"2030-01-01T00:00:00Z"}',
    '2030-01-01T00:00:00Z',
    '[{"external_company_id":"tenant-1","company_name":"Owner Ltd","country":"GB","home_currency":"GBP"}]');

select is((select count(*)::int from saved_one), 1, 'save_connections returns one row per company');
select ok((select created from saved_one), 'a new company is created');

create temporary table ids on commit drop as
  select (select connection_id from saved_one) as biz;

select ok((select auto_sync from public.accounting_connections where id = (select biz from ids)),
  'the only company of a consent starts with auto-sync on');
select isnt((select token_secret_id from public.accounting_connections where id = (select biz from ids)), null,
  'the connection points at a Vault secret');
select is((select secret from public.accounting_read_token((select biz from ids)))::jsonb->>'access_token', 'at-1',
  'read_token returns the bundle from Vault');
select is((select count(*)::int from information_schema.columns
            where table_schema = 'public' and table_name = 'accounting_connections'
              and column_name in ('access_token', 'refresh_token', 'token')), 0,
  'no plain token column exists');

-- A paused connection and one that needs re-authorisation: neither enqueues.
insert into public.accounting_connections (id, user_id, provider, external_company_id, company_name, token_secret_id, auto_sync)
values ('a3100000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'quickbooks', 'realm-1', 'Paused Co', gen_random_uuid(), false);
insert into public.accounting_connections (id, user_id, provider, external_company_id, company_name, token_secret_id, status)
values ('a3100000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', 'freeagent', 'https://api.freeagent.com/v2/company', 'Reauth Co', gen_random_uuid(), 'needs_reauth');

-- ---------------------------------------------------------------------------
-- Enqueue rules
-- ---------------------------------------------------------------------------

insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope, category)
values ('a3200000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', current_date, 'Staples', 24.00, 'expense', 'business', 'office_supplies');

select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), 1,
  'a business expense enqueues exactly one job');
select is((select connection_id from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), (select biz from ids),
  'the job is for the active auto-sync connection only (not paused, not needs_reauth)');
select is((select action::text from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), 'create',
  'an unsynced transaction enqueues create');

insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', current_date, 'Cinema', 12.00, 'expense', 'personal');
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000002'), 0,
  'an expense outside the sync scope enqueues nothing');

insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', current_date, 'Client', 500.00, 'income', 'business');
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000003'), 0,
  'income enqueues nothing');

insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000004', 'a3000000-0000-0000-0000-000000000002', current_date, 'Other', 5.00, 'expense', 'business');
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000004'), 0,
  'another user''s expense never enqueues on this user''s connection');

-- Dedupe: edits before the worker runs keep one queued job.
update public.money_transactions set amount = 25.00 where id = 'a3200000-0000-0000-0000-000000000001';
update public.money_transactions set merchant = 'Staples UK' where id = 'a3200000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), 1,
  'repeated edits dedupe into one pending job');

update public.money_transactions set notes = notes where id = 'a3200000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), 1,
  'an update that changes nothing synced enqueues nothing');

-- FX backfill (Phase 4) rewrites home_amount, which also bumps sync_seq and
-- updated_at; providers never receive it, so it must not enqueue.
update public.accounting_sync_jobs set status = 'succeeded' where transaction_id = 'a3200000-0000-0000-0000-000000000001';
update public.money_transactions set home_amount = 21.50 where id = 'a3200000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001' and status = 'pending'), 0,
  'a home_amount-only update (FX backfill) enqueues nothing');
update public.accounting_sync_jobs set status = 'pending' where transaction_id = 'a3200000-0000-0000-0000-000000000001';

-- Soft delete of a never-synced expense: the queued create is dropped.
update public.money_transactions set deleted_at = now() where id = 'a3200000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000001'), 0,
  'soft-deleting an expense that never reached the provider drops its queued job');

-- A synced expense: edits enqueue update, soft delete enqueues delete.
insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000005', 'a3000000-0000-0000-0000-000000000001', current_date, 'Adobe', 60.00, 'expense', 'business');
update public.accounting_sync_jobs set status = 'succeeded' where transaction_id = 'a3200000-0000-0000-0000-000000000005';
insert into public.accounting_links (transaction_id, connection_id, user_id, external_id, external_type)
values ('a3200000-0000-0000-0000-000000000005', (select biz from ids), 'a3000000-0000-0000-0000-000000000001', 'bt-1', 'SPEND');

update public.money_transactions set amount = 61.00 where id = 'a3200000-0000-0000-0000-000000000005';
select is((select action::text from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000005' and status = 'pending'), 'update',
  'editing a synced expense enqueues update');

update public.money_transactions set deleted_at = now() where id = 'a3200000-0000-0000-0000-000000000005';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000005' and status = 'pending'), 1,
  'soft delete reuses the pending job');
select is((select action::text from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000005' and status = 'pending'), 'delete',
  'soft-deleting a synced expense enqueues delete');

-- Moving a synced expense out of the business scope removes it from the ledger.
insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000006', 'a3000000-0000-0000-0000-000000000001', current_date, 'Taxi', 18.00, 'expense', 'business');
update public.accounting_sync_jobs set status = 'succeeded' where transaction_id = 'a3200000-0000-0000-0000-000000000006';
insert into public.accounting_links (transaction_id, connection_id, user_id, external_id, external_type)
values ('a3200000-0000-0000-0000-000000000006', (select biz from ids), 'a3000000-0000-0000-0000-000000000001', 'bt-2', 'SPEND');
update public.money_transactions set scope = 'personal' where id = 'a3200000-0000-0000-0000-000000000006';
select is((select action::text from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000006' and status = 'pending'), 'delete',
  'a synced expense moved to personal enqueues delete');

-- A job waiting out its backoff starts over when the user edits again.
insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000007', 'a3000000-0000-0000-0000-000000000001', current_date, 'Printer', 90.00, 'expense', 'business');
update public.accounting_sync_jobs set status = 'failed', attempts = 3, next_attempt_at = now() + interval '2 hours', last_error = 'No expense account'
 where transaction_id = 'a3200000-0000-0000-0000-000000000007';
update public.money_transactions set category = 'office_supplies' where id = 'a3200000-0000-0000-0000-000000000007';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000007'), 1,
  'a failed job is reused, not duplicated');
select is((select row(status::text, attempts, next_attempt_at <= now(), last_error)::text from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000007'),
  row('pending', 0, true, null::text)::text,
  'a fresh edit resets the failed job to pending, due now, with no attempts spent');

-- While a job is running, an edit queues another one behind it.
update public.accounting_sync_jobs set status = 'running', locked_at = now() where transaction_id = 'a3200000-0000-0000-0000-000000000007';
update public.money_transactions set amount = 91.00 where id = 'a3200000-0000-0000-0000-000000000007';
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000007'), 2,
  'an edit during a running job queues a follow-up job');

-- Pausing auto-sync stops enqueueing.
update public.accounting_connections set auto_sync = false where id = (select biz from ids);
insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000008', 'a3000000-0000-0000-0000-000000000001', current_date, 'Paused', 10.00, 'expense', 'business');
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000008'), 0,
  'nothing is enqueued while auto-sync is paused');
update public.accounting_connections set auto_sync = true where id = (select biz from ids);

-- ---------------------------------------------------------------------------
-- Claim
-- ---------------------------------------------------------------------------

delete from public.accounting_sync_jobs;

-- A second grant (another user) to show that claims span grants.
create temporary table saved_other on commit drop as
  select * from public.accounting_save_connections(
    'a3000000-0000-0000-0000-000000000002', 'quickbooks',
    '{"access_token":"at-2","refresh_token":"rt-2","expires_at":"2030-01-01T00:00:00Z"}',
    '2030-01-01T00:00:00Z',
    '[{"external_company_id":"realm-9","company_name":"Other Co"}]');

insert into public.accounting_sync_jobs (id, user_id, connection_id, transaction_id, action, next_attempt_at, created_at) values
  ('a3300000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', (select biz from ids), 'a3200000-0000-0000-0000-000000000005', 'update', now() - interval '3 minutes', now() - interval '3 minutes'),
  ('a3300000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', (select biz from ids), 'a3200000-0000-0000-0000-000000000006', 'delete', now() - interval '2 minutes', now() - interval '2 minutes'),
  ('a3300000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', (select biz from ids), 'a3200000-0000-0000-0000-000000000007', 'create', now() - interval '1 minute', now() - interval '1 minute'),
  ('a3300000-0000-0000-0000-000000000004', 'a3000000-0000-0000-0000-000000000001', (select biz from ids), 'a3200000-0000-0000-0000-000000000002', 'create', now() + interval '1 hour', now()),
  ('a3300000-0000-0000-0000-000000000005', 'a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000002', 'a3200000-0000-0000-0000-000000000008', 'create', now() - interval '10 minutes', now()),
  ('a3300000-0000-0000-0000-000000000006', 'a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000003', 'a3200000-0000-0000-0000-000000000008', 'create', now() - interval '10 minutes', now()),
  ('a3300000-0000-0000-0000-000000000007', 'a3000000-0000-0000-0000-000000000002', (select connection_id from saved_other), 'a3200000-0000-0000-0000-000000000004', 'create', now() - interval '30 seconds', now());
update public.accounting_sync_jobs set status = 'failed', attempts = 1 where id = 'a3300000-0000-0000-0000-000000000003';

create temporary table claim1 on commit drop as select * from public.claim_accounting_sync_jobs(2);
select is((select array_agg(id::text order by next_attempt_at) from claim1),
  array['a3300000-0000-0000-0000-000000000001', 'a3300000-0000-0000-0000-000000000002'],
  'claim takes the oldest due jobs first, up to the limit');
select is((select count(*)::int from public.accounting_sync_jobs where id in (select id from claim1) and status = 'running' and locked_at is not null), 2,
  'claimed jobs are marked running and locked');

create temporary table claim2 on commit drop as select * from public.claim_accounting_sync_jobs(10);
select is((select array_agg(id::text) from claim2), array['a3300000-0000-0000-0000-000000000007'],
  'while a grant has running jobs, its other due jobs are held back; other grants are still claimed');
select is((select status::text from public.accounting_sync_jobs where id = 'a3300000-0000-0000-0000-000000000004'), 'pending',
  'a job not yet due is not claimed');
select is((select count(*)::int from public.accounting_sync_jobs where id in ('a3300000-0000-0000-0000-000000000005', 'a3300000-0000-0000-0000-000000000006') and status = 'pending'), 2,
  'jobs of paused or needs_reauth connections are not claimed');

-- The worker finished one and died on the other: after 15 minutes it is reclaimed.
update public.accounting_sync_jobs set status = 'succeeded', locked_at = null where id = 'a3300000-0000-0000-0000-000000000001';
update public.accounting_sync_jobs set locked_at = now() - interval '20 minutes' where id = 'a3300000-0000-0000-0000-000000000002';
update public.accounting_sync_jobs set status = 'succeeded', locked_at = null where id = 'a3300000-0000-0000-0000-000000000007';
create temporary table claim3 on commit drop as select * from public.claim_accounting_sync_jobs(10);
select is((select array_agg(id::text order by next_attempt_at) from claim3),
  array['a3300000-0000-0000-0000-000000000002', 'a3300000-0000-0000-0000-000000000003'],
  'a stale running job and the failed job due for retry are claimed together');
select is((select attempts from public.accounting_sync_jobs where id = 'a3300000-0000-0000-0000-000000000002'), 1,
  'reclaiming from a dead worker counts as an attempt');
select is((select attempts from public.accounting_sync_jobs where id = 'a3300000-0000-0000-0000-000000000003'), 1,
  'claiming a failed job does not spend an attempt by itself');
select is((select count(*)::int from public.claim_accounting_sync_jobs(10)), 0,
  'claiming again returns nothing while those run');

update public.accounting_sync_jobs set attempts = 5, locked_at = now() - interval '20 minutes' where id = 'a3300000-0000-0000-0000-000000000003';
update public.accounting_sync_jobs set status = 'succeeded', locked_at = null where id = 'a3300000-0000-0000-0000-000000000002';
select is((select count(*)::int from public.claim_accounting_sync_jobs(10)), 0, 'a job whose worker died five times is not claimed again');
select is((select status::text from public.accounting_sync_jobs where id = 'a3300000-0000-0000-0000-000000000003'), 'dead',
  '… and is marked dead');

-- ---------------------------------------------------------------------------
-- Vault token lifecycle
-- ---------------------------------------------------------------------------

create temporary table old_secret on commit drop as
  select token_secret_id as id from public.accounting_connections where id = (select biz from ids);
create temporary table new_secret on commit drop as
  select public.accounting_replace_token((select id from old_secret),
    '{"access_token":"at-1b","refresh_token":"rt-1b","expires_at":"2031-01-01T00:00:00Z"}', '2031-01-01T00:00:00Z') as id;
select isnt((select id from new_secret), null, 'replace_token stores the refreshed bundle');
select is((select token_secret_id from public.accounting_connections where id = (select biz from ids)), (select id from new_secret),
  'the connection points at the new secret');
select is((select count(*)::int from vault.secrets where id = (select id from old_secret)), 0,
  'the old secret is deleted');
select is(public.accounting_replace_token((select id from old_secret), '{"access_token":"late"}', now()), null,
  'a refresh that lost the race changes nothing');

-- One consent, two companies: one shared secret, both paused.
create temporary table saved_two on commit drop as
  select * from public.accounting_save_connections(
    'a3000000-0000-0000-0000-000000000001', 'fatture_in_cloud',
    '{"access_token":"at-3","refresh_token":"rt-3","expires_at":"2030-01-01T00:00:00Z"}',
    '2030-01-01T00:00:00Z',
    '[{"external_company_id":"111","company_name":"Uno Srl"},{"external_company_id":"222","company_name":"Due Srl"}]');
select is((select count(distinct token_secret_id)::int from public.accounting_connections where id in (select connection_id from saved_two)), 1,
  'companies of one consent share one secret');
select is((select count(*)::int from public.accounting_connections where id in (select connection_id from saved_two) and not auto_sync), 2,
  'with several companies, each starts paused');
select is((select shared_with from public.accounting_read_token((select connection_id from saved_two where company_id = '111'))), 1,
  'read_token reports the sharing connection');

select lives_ok($$select public.accounting_release_token((select connection_id from saved_two where company_id = '111'))$$,
  'release_token runs');
select is((select status::text from public.accounting_connections where id = (select connection_id from saved_two where company_id = '111')), 'revoked',
  'a released connection is revoked');
select is((select count(*)::int from vault.secrets where id = (select token_secret_id from public.accounting_connections where id = (select connection_id from saved_two where company_id = '222'))), 1,
  'the shared secret survives while another connection uses it');

-- Reconnecting a revoked company reuses its row.
create temporary table saved_again on commit drop as
  select * from public.accounting_save_connections(
    'a3000000-0000-0000-0000-000000000001', 'fatture_in_cloud',
    '{"access_token":"at-4","refresh_token":"rt-4","expires_at":"2030-01-01T00:00:00Z"}',
    '2030-01-01T00:00:00Z',
    '[{"external_company_id":"111","company_name":"Uno Srl"}]');
select is((select row(connection_id, created)::text from saved_again),
  row((select connection_id from saved_two where company_id = '111'), false)::text,
  'reconnecting a company updates its existing connection');
select is((select status::text from public.accounting_connections where id = (select connection_id from saved_again)), 'active',
  'the reconnected company is active again');

create temporary table doomed on commit drop as
  select token_secret_id as id from public.accounting_connections where id = (select connection_id from saved_again);
delete from public.accounting_connections where id = (select connection_id from saved_again);
select is((select count(*)::int from vault.secrets where id = (select id from doomed)), 0,
  'deleting a connection deletes its unused secret');

-- ---------------------------------------------------------------------------
-- Clients cannot write the queue, links or connections
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a3000000-0000-0000-0000-000000000001', true);

select ok((select count(*)::int from public.accounting_sync_jobs) > 0, 'the owner can read their sync jobs');
select throws_ok($$insert into public.accounting_sync_jobs (user_id, connection_id, transaction_id, action) values ('a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000002', gen_random_uuid(), 'create')$$,
  '42501', null, 'clients cannot insert sync jobs');
select throws_ok($$update public.accounting_sync_jobs set status = 'succeeded'$$,
  '42501', null, 'clients cannot update sync jobs');
select throws_ok($$insert into public.accounting_links (transaction_id, connection_id, user_id, external_id, external_type) values ('a3200000-0000-0000-0000-000000000002', 'a3100000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'x', 'SPEND')$$,
  '42501', null, 'clients cannot write accounting links');
select throws_ok($$update public.accounting_connections set status = 'active'$$,
  '42501', null, 'clients cannot change a connection''s status');
select throws_ok($$select public.claim_accounting_sync_jobs(10)$$,
  '42501', null, 'clients cannot claim jobs');
select throws_ok($$select * from public.accounting_read_token('a3100000-0000-0000-0000-000000000002')$$,
  '42501', null, 'clients cannot read tokens');
select throws_ok($$select * from public.accounting_save_connections('a3000000-0000-0000-0000-000000000001', 'xero', '{}', now(), '[]')$$,
  '42501', null, 'clients cannot store connections');

-- The trigger still enqueues for a client's own write (SECURITY DEFINER).
insert into public.money_transactions (id, user_id, transaction_date, merchant, amount, direction, scope)
values ('a3200000-0000-0000-0000-000000000009', 'a3000000-0000-0000-0000-000000000001', current_date, 'Client write', 7.00, 'expense', 'business');
select is((select count(*)::int from public.accounting_sync_jobs where transaction_id = 'a3200000-0000-0000-0000-000000000009'), 1,
  'a client''s own expense still enqueues through the trigger');
reset role;

select * from finish();
rollback;
