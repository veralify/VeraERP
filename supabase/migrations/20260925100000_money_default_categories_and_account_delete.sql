-- Phase 0 (iOS sign-in and sync): default categories and account deletion.
-- See money-manager-ios/docs/RECEIPTS_CONTRACTS.md §3.
--
-- 1. Every account starts with the same category keys, so the phone, the web
--    and the receipt reader agree on what "groceries" is. Seeded here when a
--    profile is created; the iOS first sync seeds the same list for accounts
--    this migration missed, and only when the server has none.
-- 2. The account-delete function deletes the auth user, and everything that
--    references the profile goes with it by cascade. Accounting tokens are the
--    exception: they sit in Vault, referenced by id, and no foreign key would
--    remove them — so they are deleted first, here.

-- ---------------------------------------------------------------------------
-- Default categories
-- ---------------------------------------------------------------------------

-- All or nothing: an account that already has any category row (including a
-- deleted one) is left alone, so a category the user removed is never put back.
create or replace function public.money_seed_default_categories(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  inserted integer;
begin
  if exists (select 1 from public.money_categories where user_id = p_user_id) then
    return 0;
  end if;

  insert into public.money_categories (user_id, key, name, icon, kind, sort_order)
  select p_user_id, d.key, d.name, d.icon, 'expense', d.sort_order
  from (values
    ('groceries', 'Groceries', 'cart.fill', 0),
    ('eating_out', 'Eating out', 'fork.knife', 1),
    ('transport', 'Transport', 'tram.fill', 2),
    ('fuel', 'Fuel', 'fuelpump.fill', 3),
    ('housing', 'Housing', 'house.fill', 4),
    ('utilities', 'Utilities', 'bolt.fill', 5),
    ('shopping', 'Shopping', 'bag.fill', 6),
    ('health', 'Health', 'cross.case.fill', 7),
    ('entertainment', 'Entertainment', 'film.fill', 8),
    ('travel', 'Travel', 'airplane', 9),
    ('subscriptions', 'Subscriptions', 'repeat', 10),
    ('office_supplies', 'Office supplies', 'paperclip', 11),
    ('software', 'Software', 'laptopcomputer', 12),
    ('professional_services', 'Professional services', 'briefcase.fill', 13),
    ('education', 'Education', 'graduationcap.fill', 14),
    ('gifts_donations', 'Gifts & donations', 'gift.fill', 15),
    ('fees_charges', 'Fees & charges', 'percent', 16),
    ('other', 'Other', 'square.grid.2x2.fill', 17)
  ) as d(key, name, icon, sort_order);

  get diagnostics inserted = row_count;
  return inserted;
end;
$$;

revoke all on function public.money_seed_default_categories(uuid) from public, anon, authenticated;
grant execute on function public.money_seed_default_categories(uuid) to service_role;

create or replace function public.money_seed_categories_for_new_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.money_seed_default_categories(new.id);
  return new;
end;
$$;

revoke all on function public.money_seed_categories_for_new_profile() from public, anon, authenticated;

create trigger money_seed_categories_on_profile
  after insert on public.profiles
  for each row execute function public.money_seed_categories_for_new_profile();

-- Existing accounts that already use the money module. Accounts that never
-- have are seeded by their first iOS sync, rather than giving every profile
-- in the product eighteen rows it may never use.
select public.money_seed_default_categories(p.id)
from public.profiles p
where exists (select 1 from public.money_income where user_id = p.id)
   or exists (select 1 from public.money_expenses where user_id = p.id)
   or exists (select 1 from public.money_debts where user_id = p.id)
   or exists (select 1 from public.money_transactions where user_id = p.id)
   or exists (select 1 from public.money_settings where user_id = p.id)
   or exists (select 1 from public.money_budgets where user_id = p.id);

-- ---------------------------------------------------------------------------
-- Account deletion
-- ---------------------------------------------------------------------------

-- Deletes the Vault secrets holding the user's accounting OAuth tokens. Called
-- by the account-delete function (service role) just before it deletes the
-- auth user; the connection rows themselves then go by cascade. Returns how
-- many secrets were removed.
create or replace function public.account_delete_vault_secrets(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  removed integer;
begin
  -- VERIFY: on hosted Supabase the migration role (postgres, owner of this
  -- function) may delete from vault.secrets directly.
  delete from vault.secrets s
  using public.accounting_connections c
  where c.user_id = p_user_id
    and c.token_secret_id is not null
    and s.id = c.token_secret_id;
  get diagnostics removed = row_count;
  return removed;
end;
$$;

revoke all on function public.account_delete_vault_secrets(uuid) from public, anon, authenticated;
grant execute on function public.account_delete_vault_secrets(uuid) to service_role;
