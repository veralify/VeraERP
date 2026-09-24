-- Forwarding address for e-mailed receipts: receipts+{token}@<inbound domain>.
--
-- money_inbound_addresses (foundation migration) is read-only to its owner,
-- so the address is created and rotated here, through functions that only
-- ever act on the caller's own row. The domain is not stored: it is the
-- INBOUND_EMAIL_DOMAIN function secret, and clients compose the address from
-- the token.
--
-- Rotating replaces the token, so the old address stops working at once —
-- the remedy when an address has leaked and started receiving spam.

create or replace function public.money_inbound_address(p_rotate boolean default false)
returns table (token text, enabled boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
#variable_conflict use_column
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sign in to get a receipts address.' using errcode = '42501';
  end if;

  insert into public.money_inbound_addresses (user_id)
  values (v_user)
  on conflict (user_id) do nothing;

  if p_rotate then
    update public.money_inbound_addresses a
       set token = encode(extensions.gen_random_bytes(12), 'hex'),
           created_at = now()
     where a.user_id = v_user;
  end if;

  return query
    select a.token, a.enabled, a.created_at
      from public.money_inbound_addresses a
     where a.user_id = v_user;
end;
$$;

-- Pause or resume forwarding without losing the address.
create or replace function public.money_set_inbound_address_enabled(p_enabled boolean)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Sign in to change your receipts address.' using errcode = '42501';
  end if;
  if p_enabled is null then
    raise exception 'p_enabled is required.' using errcode = '22004';
  end if;

  insert into public.money_inbound_addresses (user_id, enabled)
  values (v_user, p_enabled)
  on conflict (user_id) do update set enabled = excluded.enabled;
  return p_enabled;
end;
$$;

revoke all on function public.money_inbound_address(boolean) from public, anon;
revoke all on function public.money_set_inbound_address_enabled(boolean) from public, anon;
grant execute on function public.money_inbound_address(boolean) to authenticated, service_role;
grant execute on function public.money_set_inbound_address_enabled(boolean) to authenticated, service_role;
