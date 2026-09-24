-- Accounting integrations (Phase 3): the sync queue, its claim function and
-- the Vault plumbing for OAuth tokens. Tables are in
-- 20260925090000_money_receipts_sync_foundation.sql; the contract is
-- money-manager-ios/docs/RECEIPTS_CONTRACTS.md §6.
--
-- Schedule the worker once the function URL and service key exist, the same
-- way as notification-worker (never hard-code the key in a migration; keep it
-- in Vault and read it in the cron command):
--
-- select cron.schedule(
--   'accounting-sync-every-minute',
--   '* * * * *',
--   $$select net.http_post(
--       url := 'https://<project-ref>.supabase.co/functions/v1/accounting-sync',
--       headers := jsonb_build_object(
--         'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
--         'Content-Type', 'application/json'),
--       body := jsonb_build_object('limit', 20)
--     );$$
-- );

-- ---------------------------------------------------------------------------
-- Indexes the trigger and the worker lean on
-- ---------------------------------------------------------------------------

-- The trigger looks for a queued job of the same transaction+connection on
-- every relevant write (dedupe).
create index idx_accounting_jobs_queued_pair on public.accounting_sync_jobs(transaction_id, connection_id)
  where status in ('pending', 'failed', 'running');

-- Token refreshes and the claim's "is this grant busy" check go by secret.
create index idx_accounting_connections_token on public.accounting_connections(token_secret_id)
  where token_secret_id is not null;

create index idx_accounting_connections_user_active on public.accounting_connections(user_id)
  where status = 'active' and auto_sync;

-- ---------------------------------------------------------------------------
-- Enqueue: expense transactions → accounting_sync_jobs
-- ---------------------------------------------------------------------------

-- A job only says "this transaction changed for this connection". The worker
-- always reconciles the provider with the row's *current* state, so the
-- action here is a hint for people reading the queue, and deduplication is
-- safe: one queued job per transaction+connection is enough however many
-- edits happen before it runs.
--
-- Rules, per active connection of the owner with auto_sync on:
-- * the row is an undeleted expense in the connection's sync_scope
--     → create (no accounting_links row yet) or update (linked);
-- * otherwise, if it was synced (linked) or is being synced right now
--     → delete;
-- * otherwise it never reached the provider → drop anything still queued.
-- Updates that touch none of the columns a provider receives enqueue
-- nothing: a no-op upsert from a phone re-pushing an unchanged row, or the
-- FX backfill rewriting home_amount (which also moves sync_seq/updated_at).
-- occurred_at is left out too: providers get transaction_date.
create or replace function public.accounting_enqueue_transaction_sync()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_connection record;
  v_wanted boolean;
  v_action public.accounting_job_action;
begin
  if tg_op = 'UPDATE' then
    if (old.user_id, old.transaction_date, old.merchant, old.amount, old.direction, old.category,
        old.account, old.notes, old.currency, old.tax_amount, old.scope, old.receipt_id, old.deleted_at)
       is not distinct from
       (new.user_id, new.transaction_date, new.merchant, new.amount, new.direction, new.category,
        new.account, new.notes, new.currency, new.tax_amount, new.scope, new.receipt_id, new.deleted_at) then
      return null;
    end if;
    if old.direction <> 'expense' and new.direction <> 'expense' then
      return null;
    end if;
  elsif new.direction <> 'expense' then
    return null;
  end if;

  for v_connection in
    select c.id, c.sync_scope
      from public.accounting_connections c
     where c.user_id = new.user_id
       and c.status = 'active'
       and c.auto_sync
  loop
    v_wanted := new.deleted_at is null
      and new.direction = 'expense'
      and new.scope = v_connection.sync_scope;

    if v_wanted then
      v_action := case
        when exists (select 1 from public.accounting_links l
                      where l.transaction_id = new.id and l.connection_id = v_connection.id)
        then 'update' else 'create' end;
    elsif exists (select 1 from public.accounting_links l
                   where l.transaction_id = new.id and l.connection_id = v_connection.id)
       or exists (select 1 from public.accounting_sync_jobs j
                   where j.transaction_id = new.id and j.connection_id = v_connection.id
                     and j.status = 'running') then
      -- A running job may be creating the record this very moment; the
      -- delete job runs after it and removes what it made.
      v_action := 'delete';
    else
      delete from public.accounting_sync_jobs j
       where j.transaction_id = new.id
         and j.connection_id = v_connection.id
         and j.status in ('pending', 'failed');
      continue;
    end if;

    -- A fresh edit is a fresh intent: a job waiting out its backoff starts
    -- over, so a fix the user just made goes out now.
    update public.accounting_sync_jobs j
       set action = v_action,
           status = 'pending',
           attempts = 0,
           next_attempt_at = now(),
           last_error = null
     where j.transaction_id = new.id
       and j.connection_id = v_connection.id
       and j.status in ('pending', 'failed');
    if not found then
      -- None queued, or only a running one (which may be sending the old
      -- values): queue another.
      insert into public.accounting_sync_jobs (user_id, connection_id, transaction_id, action)
      values (new.user_id, v_connection.id, new.id, v_action);
    end if;
  end loop;
  return null;
end;
$$;

revoke all on function public.accounting_enqueue_transaction_sync() from public, anon, authenticated;

create trigger money_transactions_accounting_sync
  after insert or update on public.money_transactions
  for each row execute function public.accounting_enqueue_transaction_sync();

-- ---------------------------------------------------------------------------
-- Claim: hand due jobs to one worker
-- ---------------------------------------------------------------------------

-- Returns up to p_limit due jobs (pending/failed with next_attempt_at passed,
-- or running jobs whose worker died more than 15 minutes ago), marked running.
--
-- Beyond FOR UPDATE SKIP LOCKED on the jobs themselves, it never hands out
-- jobs for a token bundle that another worker is still using: a refresh
-- rotates the refresh token (Xero, QuickBooks), and two workers refreshing
-- the same grant would leave one holding a dead token. Grants are taken one
-- at a time under a transaction-scoped advisory lock, and the "is anyone
-- running jobs on it" check is its own statement, so it sees any claim
-- committed while this one waited.
create or replace function public.claim_accounting_sync_jobs(p_limit integer default 20)
returns setof public.accounting_sync_jobs
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_remaining integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_token uuid;
  v_claimed integer;
begin
  -- A job whose worker died five times is not going to succeed on a sixth.
  update public.accounting_sync_jobs j
     set status = 'dead',
         locked_at = null,
         last_error = coalesce(j.last_error, 'Worker stopped while processing this job')
   where j.status = 'running'
     and j.locked_at < now() - interval '15 minutes'
     and j.attempts >= 5;

  for v_token in
    select c.token_secret_id
      from public.accounting_sync_jobs j
      join public.accounting_connections c on c.id = j.connection_id
     where c.status = 'active'
       and c.auto_sync
       and c.token_secret_id is not null
       and ((j.status in ('pending', 'failed') and j.next_attempt_at <= now())
            or (j.status = 'running' and j.locked_at < now() - interval '15 minutes'))
     group by c.token_secret_id
     order by min(j.next_attempt_at), c.token_secret_id
  loop
    exit when v_remaining <= 0;
    continue when not pg_try_advisory_xact_lock(
      hashtextextended('accounting_sync_token:' || v_token::text, 0));
    continue when exists (
      select 1
        from public.accounting_sync_jobs j
        join public.accounting_connections c on c.id = j.connection_id
       where c.token_secret_id = v_token
         and j.status = 'running'
         and j.locked_at >= now() - interval '15 minutes');

    return query
      with picked as (
        select j.id
          from public.accounting_sync_jobs j
          join public.accounting_connections c on c.id = j.connection_id
         where c.token_secret_id = v_token
           and c.status = 'active'
           and c.auto_sync
           and ((j.status in ('pending', 'failed') and j.next_attempt_at <= now())
                or (j.status = 'running' and j.locked_at < now() - interval '15 minutes'))
         order by j.next_attempt_at, j.created_at
         limit v_remaining
         for update of j skip locked
      ), claimed as (
        update public.accounting_sync_jobs j
           set status = 'running',
               locked_at = now(),
               -- Reclaiming from a dead worker counts as a failed attempt.
               attempts = j.attempts + case when j.status = 'running' then 1 else 0 end
          from picked
         where j.id = picked.id
        returning j.*
      )
      select * from claimed order by claimed.next_attempt_at, claimed.created_at;
    get diagnostics v_claimed = row_count;
    v_remaining := v_remaining - v_claimed;
  end loop;
end;
$$;

revoke all on function public.claim_accounting_sync_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_accounting_sync_jobs(integer) to service_role;

-- ---------------------------------------------------------------------------
-- Tokens in Vault
-- ---------------------------------------------------------------------------
-- The OAuth token bundle (JSON) lives only in vault.secrets, encrypted at
-- rest; accounting_connections.token_secret_id points at it. The Vault schema
-- is not exposed through PostgREST, so the edge functions reach it only
-- through these SECURITY DEFINER functions, executable by service_role alone.
--
-- One consent can cover several companies (Xero organisations, Fatture in
-- Cloud companies) with a single token, so several connections may point at
-- the same secret: a refresh must update all of them at once, and a secret is
-- deleted only when no connection uses it any more.

-- Internal: drop a secret nobody points at.
create or replace function public.accounting_delete_secret_if_unused(p_secret_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_secret_id is not null
     and not exists (select 1 from public.accounting_connections c where c.token_secret_id = p_secret_id) then
    -- VERIFY: on hosted Supabase the migration owner (postgres) may delete
    -- from vault.secrets; this is how the dashboard removes a secret too.
    delete from vault.secrets s where s.id = p_secret_id;
  end if;
end;
$$;

-- Stores a fresh grant and upserts one connection per company, atomically.
-- p_companies: [{ "external_company_id", "company_name", "country", "home_currency" }].
-- A company connected before keeps its row (mappings, links, sync settings)
-- and gets the new token; a new one starts with auto_sync on only when it is
-- the sole company of the consent (see accounting-callback for why).
create or replace function public.accounting_save_connections(
  p_user_id uuid,
  p_provider public.accounting_provider,
  p_secret text,
  p_expires_at timestamptz,
  p_companies jsonb
)
returns table (connection_id uuid, company_id text, created boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := jsonb_array_length(coalesce(p_companies, '[]'::jsonb));
  v_secret_id uuid;
  v_company jsonb;
  v_existing record;
  v_id uuid;
begin
  if v_count = 0 then
    raise exception 'accounting_save_connections: no companies' using errcode = '22023';
  end if;
  if p_secret is null or p_secret = '' then
    raise exception 'accounting_save_connections: empty token bundle' using errcode = '22023';
  end if;

  v_secret_id := vault.create_secret(
    p_secret,
    'accounting_token_' || gen_random_uuid()::text,
    'Accounting OAuth token bundle (' || p_provider::text || ')');

  for v_company in select value from jsonb_array_elements(p_companies) loop
    select c.id, c.token_secret_id into v_existing
      from public.accounting_connections c
     where c.user_id = p_user_id
       and c.provider = p_provider
       and c.external_company_id = v_company->>'external_company_id'
     for update;

    if found then
      update public.accounting_connections c
         set token_secret_id = v_secret_id,
             token_expires_at = p_expires_at,
             status = 'active',
             last_error = null,
             company_name = coalesce(nullif(v_company->>'company_name', ''), c.company_name),
             country = coalesce(v_company->>'country', c.country),
             home_currency = coalesce(v_company->>'home_currency', c.home_currency)
       where c.id = v_existing.id;
      perform public.accounting_delete_secret_if_unused(v_existing.token_secret_id);
      connection_id := v_existing.id;
      created := false;
    else
      insert into public.accounting_connections
        (user_id, provider, external_company_id, company_name, country, home_currency,
         token_secret_id, token_expires_at, auto_sync)
      values
        (p_user_id, p_provider, v_company->>'external_company_id',
         coalesce(v_company->>'company_name', ''), v_company->>'country', v_company->>'home_currency',
         v_secret_id, p_expires_at, v_count = 1)
      returning id into v_id;
      connection_id := v_id;
      created := true;
    end if;
    company_id := v_company->>'external_company_id';
    return next;
  end loop;
end;
$$;

-- The token bundle of a connection, plus how many other connections share it
-- (a disconnect must then detach only this company, not revoke the grant).
create or replace function public.accounting_read_token(p_connection_id uuid)
returns table (token_secret_id uuid, secret text, shared_with integer)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select c.token_secret_id,
         s.decrypted_secret::text,
         (select count(*)::integer
            from public.accounting_connections o
           where o.token_secret_id = c.token_secret_id
             and o.id <> c.id)
    from public.accounting_connections c
    join vault.decrypted_secrets s on s.id = c.token_secret_id
   where c.id = p_connection_id;
$$;

-- Stores a refreshed bundle. Compare-and-swap on the secret id: if another
-- process already replaced p_old_secret_id, nothing changes and null comes
-- back (the caller then re-reads and uses the winner's token). A new secret
-- is written rather than updating in place so the swap is atomic for every
-- connection sharing the grant.
create or replace function public.accounting_replace_token(
  p_old_secret_id uuid,
  p_secret text,
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_new uuid;
begin
  perform 1 from public.accounting_connections c where c.token_secret_id = p_old_secret_id for update;
  if not found then
    return null;
  end if;
  v_new := vault.create_secret(
    p_secret,
    'accounting_token_' || gen_random_uuid()::text,
    'Accounting OAuth token bundle');
  update public.accounting_connections c
     set token_secret_id = v_new,
         token_expires_at = p_expires_at
   where c.token_secret_id = p_old_secret_id;
  perform public.accounting_delete_secret_if_unused(p_old_secret_id);
  return v_new;
end;
$$;

-- Disconnect: forget the token (deleting the secret unless another
-- connection still shares it) and mark the connection revoked.
create or replace function public.accounting_release_token(p_connection_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_old uuid;
begin
  select c.token_secret_id into v_old
    from public.accounting_connections c
   where c.id = p_connection_id
   for update;
  update public.accounting_connections c
     set token_secret_id = null,
         token_expires_at = null,
         status = 'revoked',
         last_error = null
   where c.id = p_connection_id;
  perform public.accounting_delete_secret_if_unused(v_old);
end;
$$;

-- A connection deleted any other way (account deletion cascades) must not
-- leave its token behind in Vault.
create or replace function public.accounting_connection_deleted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.accounting_delete_secret_if_unused(old.token_secret_id);
  return null;
end;
$$;

create trigger accounting_connections_forget_token
  after delete on public.accounting_connections
  for each row execute function public.accounting_connection_deleted();

revoke all on function public.accounting_delete_secret_if_unused(uuid) from public, anon, authenticated;
revoke all on function public.accounting_save_connections(uuid, public.accounting_provider, text, timestamptz, jsonb) from public, anon, authenticated;
revoke all on function public.accounting_read_token(uuid) from public, anon, authenticated;
revoke all on function public.accounting_replace_token(uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.accounting_release_token(uuid) from public, anon, authenticated;
revoke all on function public.accounting_connection_deleted() from public, anon, authenticated;

grant execute on function public.accounting_save_connections(uuid, public.accounting_provider, text, timestamptz, jsonb) to service_role;
grant execute on function public.accounting_read_token(uuid) to service_role;
grant execute on function public.accounting_replace_token(uuid, text, timestamptz) to service_role;
grant execute on function public.accounting_release_token(uuid) to service_role;
