-- Phase 3 commerce rail: canonical plan/product configuration and entitlement projection.
-- Ambiguity resolved: the requested trial flag is represented as the normalized entitlement key `trial_active`; frozen feature keys from §35/§38 remain unchanged.

insert into public.plans (id, code, name, description, is_active)
values
  ('70000000-0000-0000-0000-000000000001', 'VERALIFY_PRO', 'Veralify Pro', 'Consumer subscription: full AI, tracking, groups, progress analytics, live rooms, and coach discovery.', true),
  ('70000000-0000-0000-0000-000000000002', 'VERALIFY_COACH', 'Veralify Coach', 'Coach tools subscription: Pro plus coach dashboard, client management, scheduling, and sessions.', true)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  updated_at = now();

with plan_ids as (
  select code, id from public.plans where code in ('VERALIFY_PRO', 'VERALIFY_COACH')
)
insert into public.billing_products (plan_id, provider, provider_product_id, billing_period, is_active)
select p.id, v.provider::public.billing_provider, v.provider_product_id, v.billing_period::public.billing_period, true
from (values
  ('VERALIFY_PRO', 'apple', 'veralify.pro.weekly', 'weekly'),
  ('VERALIFY_PRO', 'apple', 'veralify.pro.monthly', 'monthly'),
  ('VERALIFY_PRO', 'apple', 'veralify.pro.annual', 'annual'),
  ('VERALIFY_COACH', 'apple', 'veralify.coach.monthly', 'monthly'),
  ('VERALIFY_PRO', 'stripe', 'env:STRIPE_VERALIFY_PRO_WEEKLY_PRODUCT_ID', 'weekly'),
  ('VERALIFY_PRO', 'stripe', 'env:STRIPE_VERALIFY_PRO_MONTHLY_PRODUCT_ID', 'monthly'),
  ('VERALIFY_PRO', 'stripe', 'env:STRIPE_VERALIFY_PRO_ANNUAL_PRODUCT_ID', 'annual'),
  ('VERALIFY_COACH', 'stripe', 'env:STRIPE_VERALIFY_COACH_MONTHLY_PRODUCT_ID', 'monthly')
) as v(plan_code, provider, provider_product_id, billing_period)
join plan_ids p on p.code = v.plan_code
on conflict (provider, provider_product_id) do update set
  plan_id = excluded.plan_id,
  billing_period = excluded.billing_period,
  is_active = true,
  updated_at = now();

with plan_ids as (
  select code, id from public.plans where code in ('VERALIFY_PRO', 'VERALIFY_COACH')
), entitlements as (
  select 'VERALIFY_PRO' as plan_code, unnest(array[
    'ai_food_logging', 'advanced_ai', 'daily_summary', 'advanced_nutrition',
    'unlimited_groups', 'advanced_progress', 'progress_photos', 'advanced_trends',
    'live_rooms', 'premium_live_rooms', 'coach_discovery'
  ]) as lookup_key
  union all
  select 'VERALIFY_COACH', unnest(array[
    'ai_food_logging', 'advanced_ai', 'daily_summary', 'advanced_nutrition',
    'unlimited_groups', 'advanced_progress', 'progress_photos', 'advanced_trends',
    'live_rooms', 'premium_live_rooms', 'coach_discovery',
    'coach_client_management', 'coach_client_data', 'coach_video_sessions',
    'coach_group_sessions', 'coach_scheduling', 'coach_dashboard'
  ])
)
insert into public.plan_entitlements (plan_id, lookup_key, limit_value, limit_period)
select p.id, e.lookup_key, null, null
from entitlements e
join plan_ids p on p.code = e.plan_code
on conflict (plan_id, lookup_key) do update set
  limit_value = excluded.limit_value,
  limit_period = excluded.limit_period,
  updated_at = now();

create or replace function public.project_user_entitlements(p_user_id uuid)
returns table (lookup_key text, active boolean, source public.entitlement_source, limit_value numeric, expires_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  if p_user_id is null then
    raise exception 'user_id is required' using errcode = '22004';
  end if;

  delete from public.user_entitlements
  where user_id = p_user_id
    and public.user_entitlements.source in ('stripe', 'apple');

  insert into public.user_entitlements (user_id, lookup_key, source, active, limit_value, expires_at)
  select distinct p_user_id, pe.lookup_key, 'stripe'::public.entitlement_source, true, pe.limit_value, s.current_period_end
  from public.subscriptions s
  join public.plan_entitlements pe on pe.plan_id = s.plan_id
  where s.user_id = p_user_id
    and s.status in ('trialing', 'active')
    and s.current_period_end > now()
  on conflict (user_id, lookup_key, source) do update set
    active = excluded.active,
    limit_value = excluded.limit_value,
    expires_at = excluded.expires_at,
    updated_at = now();

  insert into public.user_entitlements (user_id, lookup_key, source, active, limit_value, expires_at)
  select distinct p_user_id, 'trial_active', 'stripe'::public.entitlement_source, true, null::numeric, s.current_period_end
  from public.subscriptions s
  where s.user_id = p_user_id
    and s.status = 'trialing'
    and s.current_period_end > now()
  on conflict (user_id, lookup_key, source) do update set active = true, expires_at = excluded.expires_at, updated_at = now();

  insert into public.user_entitlements (user_id, lookup_key, source, active, limit_value, expires_at)
  select distinct p_user_id, pe.lookup_key, 'apple'::public.entitlement_source, true, pe.limit_value, i.expires_at
  from public.iap_transactions i
  join public.billing_products bp on bp.provider = 'apple' and bp.provider_product_id = i.product_id
  join public.plan_entitlements pe on pe.plan_id = bp.plan_id
  where i.user_id = p_user_id
    and i.status in ('active', 'grace_period')
    and (i.expires_at is null or i.expires_at > now())
  on conflict (user_id, lookup_key, source) do update set
    active = excluded.active,
    limit_value = excluded.limit_value,
    expires_at = excluded.expires_at,
    updated_at = now();

  return query
  select ue.lookup_key, ue.active, ue.source, ue.limit_value, ue.expires_at
  from public.user_entitlements ue
  where ue.user_id = p_user_id
    and ue.active = true
    and (ue.expires_at is null or ue.expires_at > now())
  order by ue.source, ue.lookup_key;
end;
$$;

revoke all on function public.project_user_entitlements(uuid) from public;
revoke all on function public.project_user_entitlements(uuid) from anon;
revoke all on function public.project_user_entitlements(uuid) from authenticated;
grant execute on function public.project_user_entitlements(uuid) to service_role;
