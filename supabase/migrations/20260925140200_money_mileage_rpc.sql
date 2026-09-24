-- Mileage: a trip and the expense it claims are saved together.
--
-- A logged trip is only useful in a report if its amount is also in the
-- spending, so logging one writes both rows in one transaction: the
-- money_mileage_trips row and a money_transactions expense with
-- source 'mileage', linked by transaction_id. Doing it as two PostgREST calls
-- from the web and the phone would leave an orphan whenever the second failed.
--
-- Both functions are security invoker: row security and the table grants
-- apply exactly as they would to the two inserts made directly.
--
-- The amount is computed by the client (web: reports/mileage lib; iOS:
-- VeralifyCore `Mileage`), because the UK rate depends on the business miles
-- already driven in the tax year and the client already has that list. When
-- it is not sent, it is distance × rate.

create or replace function public.money_log_mileage_trip(
  p_trip_date date,
  p_distance numeric,
  p_unit text,
  p_rate_per_unit numeric,
  p_amount numeric default null,
  p_currency text default 'EUR',
  p_origin text default '',
  p_destination text default '',
  p_purpose text default '',
  p_scope public.money_scope default 'business',
  p_id uuid default null
)
returns public.money_mileage_trips
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_amount numeric := coalesce(p_amount, round(p_distance * p_rate_per_unit, 2));
  v_origin text := btrim(coalesce(p_origin, ''));
  v_destination text := btrim(coalesce(p_destination, ''));
  v_purpose text := btrim(coalesce(p_purpose, ''));
  v_merchant text;
  v_transaction_id uuid := gen_random_uuid();
  v_trip public.money_mileage_trips;
begin
  if v_user is null then
    raise exception 'Sign in to log a trip.' using errcode = '42501';
  end if;
  if v_amount is null or v_amount < 0 then
    raise exception 'The amount must be zero or more.' using errcode = '22023';
  end if;

  -- What the expense is called in lists and in the accounting sync.
  v_merchant := case
    when v_origin <> '' and v_destination <> '' then 'Mileage: ' || v_origin || ' – ' || v_destination
    when v_purpose <> '' then 'Mileage: ' || v_purpose
    else 'Mileage'
  end;

  insert into public.money_transactions
    (id, user_id, transaction_date, merchant, amount, direction, category, notes, currency, scope, source)
  values
    (v_transaction_id, v_user, p_trip_date, left(v_merchant, 200), v_amount, 'expense', 'transport',
     v_purpose, upper(coalesce(p_currency, 'EUR')), coalesce(p_scope, 'business'), 'mileage');

  insert into public.money_mileage_trips
    (id, user_id, trip_date, origin, destination, distance, unit, rate_per_unit, currency, purpose, scope, transaction_id)
  values
    (coalesce(p_id, gen_random_uuid()), v_user, p_trip_date, v_origin, v_destination, p_distance, p_unit,
     p_rate_per_unit, upper(coalesce(p_currency, 'EUR')), v_purpose, coalesce(p_scope, 'business'), v_transaction_id)
  returning * into v_trip;

  return v_trip;
end;
$$;

-- Soft-deletes the trip and its expense together, so the spending does not
-- keep a claim for a trip that no longer exists.
create or replace function public.money_delete_mileage_trip(p_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_transaction_id uuid;
  v_found boolean;
begin
  update public.money_mileage_trips
     set deleted_at = now()
   where id = p_id and user_id = auth.uid() and deleted_at is null
  returning transaction_id, true into v_transaction_id, v_found;

  if not coalesce(v_found, false) then
    return false;
  end if;

  if v_transaction_id is not null then
    update public.money_transactions
       set deleted_at = now()
     where id = v_transaction_id and user_id = auth.uid() and deleted_at is null;
  end if;
  return true;
end;
$$;

revoke all on function public.money_log_mileage_trip(date, numeric, text, numeric, numeric, text, text, text, text, public.money_scope, uuid) from public, anon;
revoke all on function public.money_delete_mileage_trip(uuid) from public, anon;
grant execute on function public.money_log_mileage_trip(date, numeric, text, numeric, numeric, text, text, text, text, public.money_scope, uuid) to authenticated;
grant execute on function public.money_delete_mileage_trip(uuid) to authenticated;
