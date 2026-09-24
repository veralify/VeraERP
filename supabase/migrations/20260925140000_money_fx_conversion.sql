-- Multi-currency: convert with the ECB daily reference rates, and keep
-- money_transactions.home_amount filled in the user's home currency.
--
-- fx_rates (foundation migration) holds one row per ECB publication day and
-- currency, always with base EUR, written by the `fx-rates-sync` edge
-- function. Any other pair is a cross rate through EUR.
--
-- Scheduling. The ECB publishes at about 16:00 CET on TARGET working days.
-- Run the sync once a day after that with pg_cron + pg_net (enable both
-- extensions in the dashboard, and store the service role key in Vault as
-- `service_role_key`), e.g. at 15:30 UTC, which is after 16:00 in both CET
-- and CEST:
--
--   select cron.schedule(
--     'fx-rates-sync-daily',
--     '30 15 * * 1-5',
--     $$
--     select net.http_post(
--       url     := 'https://<project-ref>.supabase.co/functions/v1/fx-rates-sync',
--       headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
--       ),
--       body    := '{}'::jsonb
--     );
--     $$
--   );
--
-- The first run (empty table) backfills the ECB's 90-day history on its own;
-- POST {"backfill": true} to force that again.
--
-- It is not scheduled from this migration because the project URL and the
-- key differ per environment, and pg_cron/pg_net are not enabled everywhere
-- (local and CI databases do not have them).

-- ---------------------------------------------------------------------------
-- Rates
-- ---------------------------------------------------------------------------

-- The rate that turns one unit of `p_from` into `p_to` on `p_on`, or null.
--
-- "On" means the latest ECB publication on or before that day: there is none
-- on weekends and TARGET holidays, so a Saturday purchase uses Friday's rate.
-- Both legs of a cross rate come from the same publication day, so a pair is
-- never priced from two different days.
--
-- A rate more than 7 days older than the date is treated as missing. The
-- longest ECB gap (Easter: Thursday to Tuesday) is 5 days; anything older
-- means the sync has stopped or the date predates the history, and a stale
-- rate would be a wrong number presented as a right one.
create or replace function public.money_fx_rate(p_from text, p_to text, p_on date)
returns numeric
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_from text := upper(p_from);
  v_to text := upper(p_to);
  v_rate numeric;
begin
  if v_from is null or v_to is null or p_on is null then
    return null;
  end if;
  if v_from = v_to then
    return 1;
  end if;

  if v_from = 'EUR' then
    select r.rate into v_rate
      from public.fx_rates r
     where r.base = 'EUR' and r.quote = v_to
       and r.rate_date <= p_on and r.rate_date > p_on - 8
     order by r.rate_date desc
     limit 1;
    return v_rate;
  end if;

  if v_to = 'EUR' then
    select 1 / r.rate into v_rate
      from public.fx_rates r
     where r.base = 'EUR' and r.quote = v_from
       and r.rate_date <= p_on and r.rate_date > p_on - 8
     order by r.rate_date desc
     limit 1;
    return v_rate;
  end if;

  -- EUR→to divided by EUR→from, from one publication day.
  select t.rate / f.rate into v_rate
    from public.fx_rates f
    join public.fx_rates t
      on t.rate_date = f.rate_date and t.base = 'EUR' and t.quote = v_to
   where f.base = 'EUR' and f.quote = v_from
     and f.rate_date <= p_on and f.rate_date > p_on - 8
   order by f.rate_date desc
   limit 1;
  return v_rate;
end;
$$;

-- `amount` in `from_currency`, expressed in `to_currency` at the ECB rate
-- for `on_date`, rounded to cents. Null when there is no usable rate —
-- callers show "not converted" rather than a guess.
create or replace function public.money_convert(amount numeric, from_currency text, to_currency text, on_date date)
returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select round(amount * public.money_fx_rate(from_currency, to_currency, on_date), 2);
$$;

grant execute on function public.money_fx_rate(text, text, date) to authenticated, service_role;
grant execute on function public.money_convert(numeric, text, text, date) to authenticated, service_role;
revoke execute on function public.money_fx_rate(text, text, date) from anon;
revoke execute on function public.money_convert(numeric, text, text, date) from anon;

-- ---------------------------------------------------------------------------
-- Home currency
-- ---------------------------------------------------------------------------

-- The user's home currency from money_settings ('homeCurrency'), EUR when
-- unset or unreadable. Tolerates a JSON-quoted value ("\"GBP\"") and case,
-- since the phone and the web both write this key.
create or replace function public.money_home_currency(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select v
       from (select upper(btrim(btrim(s.value), '"')) as v
               from public.money_settings s
              where s.user_id = p_user_id and s.key = 'homeCurrency' and s.deleted_at is null) x
      where v ~ '^[A-Z]{3}$'),
    'EUR');
$$;

-- Security definer so the trigger below can read the owner's setting
-- whoever writes the row; callers only ever get their own.
revoke all on function public.money_home_currency(uuid) from public, anon, authenticated;
grant execute on function public.money_home_currency(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- home_amount on every transaction
-- ---------------------------------------------------------------------------

-- The server owns home_amount: a value sent by a client is replaced, so the
-- phone, the web and the accounting sync all read the same figure. Same
-- currency → the amount itself; otherwise the converted amount; no rate →
-- null (never a guess).
create or replace function public.money_fill_home_amount()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_home text := public.money_home_currency(new.user_id);
begin
  if new.currency = v_home then
    new.home_amount := new.amount;
  else
    new.home_amount := public.money_convert(new.amount, new.currency, v_home, new.transaction_date);
  end if;
  return new;
end;
$$;

revoke all on function public.money_fill_home_amount() from public, anon, authenticated;

create trigger money_transactions_home_amount
  before insert or update on public.money_transactions
  for each row execute function public.money_fill_home_amount();

-- Changing the home currency re-prices the user's transactions. Touching
-- `home_amount` is enough: the trigger above recomputes it. This also moves
-- them past every device's sync cursor, which is what should happen — the
-- figure every client shows has changed.
create or replace function public.money_reprice_on_home_currency()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.key = 'homeCurrency'
     and (tg_op = 'INSERT' or new.value is distinct from old.value or new.deleted_at is distinct from old.deleted_at) then
    update public.money_transactions
       set home_amount = null
     where user_id = new.user_id and deleted_at is null;
  end if;
  return null;
end;
$$;

revoke all on function public.money_reprice_on_home_currency() from public, anon, authenticated;

create trigger money_settings_reprice_home_currency
  after insert or update on public.money_settings
  for each row execute function public.money_reprice_on_home_currency();

-- Called by fx-rates-sync after new rates land: fills rows that had no rate
-- when they were saved (a transaction dated today, saved before today's
-- publication was fetched, or before a backfill). Only rows that now get a
-- number are touched, so rows with a currency the ECB does not publish are
-- not re-pulled by every device every day.
create or replace function public.money_backfill_home_amounts()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  update public.money_transactions t
     set home_amount = null
   where t.home_amount is null
     and t.deleted_at is null
     and public.money_convert(t.amount, t.currency, public.money_home_currency(t.user_id), t.transaction_date) is not null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.money_backfill_home_amounts() from public, anon, authenticated;
grant execute on function public.money_backfill_home_amounts() to service_role;

-- Rows saved before this migration.
update public.money_transactions set home_amount = null where deleted_at is null;
