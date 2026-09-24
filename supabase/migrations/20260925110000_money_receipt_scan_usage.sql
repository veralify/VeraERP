-- Phase 1: the monthly receipt-scan allowance, claimed atomically.
--
-- `receipts-extract` (supabase/functions/ai-gateway) checks the caller's
-- monthly scan limit before it asks a model to read a receipt, and counts
-- the scan afterwards. Done as "read the row, compare, write it back" from
-- the function, two scans sent at the same moment (a multi-receipt upload,
-- or a retry racing the original) could both see 99 of 100 and both go
-- through. These two functions do the check and the increment in a single
-- statement instead, so the row lock decides who gets the last scan.
--
-- Service role only: the client reads its usage (policy in the foundation
-- migration) but must never be able to reset or refund it.

-- Takes one scan from this month's allowance. Returns the month the scan was
-- counted against, or null when the allowance is used up. The month is
-- handed back so the settle call below lands on the same row even if the
-- read runs across midnight at the end of a month.
create or replace function public.money_claim_receipt_scan(p_user_id uuid, p_limit integer)
returns date
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_scans integer;
begin
  if p_user_id is null or p_limit is null or p_limit <= 0 then
    return null;
  end if;

  -- `on conflict ... where` leaves the row untouched (and returns nothing)
  -- when the allowance is spent. The conflicting row is locked before the
  -- condition is evaluated, so concurrent claims queue here and each sees
  -- the count the previous one left.
  insert into public.money_receipt_usage as u (user_id, month, scans)
  values (p_user_id, v_month, 1)
  on conflict (user_id, month) do update
    set scans = u.scans + 1
    where u.scans < p_limit
  returning u.scans into v_scans;

  if v_scans is null then
    return null;
  end if;
  return v_month;
end;
$$;

-- Closes a claimed scan. `p_counted = false` gives the scan back — used when
-- no model could be reached, so a provider outage does not eat the user's
-- allowance. The model cost is added either way (a failed attempt may still
-- have been billed).
create or replace function public.money_settle_receipt_scan(
  p_user_id uuid,
  p_month date,
  p_counted boolean,
  p_cost_usd numeric default 0
)
returns void
language plpgsql
set search_path = public, pg_temp
as $$
begin
  update public.money_receipt_usage
     set scans = case when p_counted then scans else greatest(scans - 1, 0) end,
         cost_usd = cost_usd + greatest(coalesce(p_cost_usd, 0), 0)
   where user_id = p_user_id
     and month = p_month;
end;
$$;

revoke all on function public.money_claim_receipt_scan(uuid, integer) from public, anon, authenticated;
revoke all on function public.money_settle_receipt_scan(uuid, date, boolean, numeric) from public, anon, authenticated;
grant execute on function public.money_claim_receipt_scan(uuid, integer) to service_role;
grant execute on function public.money_settle_receipt_scan(uuid, date, boolean, numeric) to service_role;
