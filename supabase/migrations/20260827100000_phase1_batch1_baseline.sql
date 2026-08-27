-- Phase 1 Batch 1 baseline infrastructure.
-- Ambiguity resolved: although §7.1 lists profiles.is_public DEFAULT true, this batch
-- mission requires private-by-default profile flags, so new profiles default private.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create type public.units_system as enum ('metric', 'imperial');
create type public.privacy_visibility as enum ('private', 'followers', 'public', 'coach');
create type public.profile_activity_level as enum ('sedentary', 'light', 'moderate', 'active', 'very_active');
create type public.goal_status as enum ('active', 'paused', 'completed', 'cancelled');
create type public.goal_period as enum ('daily', 'weekly', 'monthly', 'overall');
create type public.meal_type as enum ('breakfast', 'lunch', 'dinner', 'snack', 'other');
create type public.food_log_source as enum ('manual', 'barcode', 'photo', 'ai', 'import');
create type public.measurement_type as enum ('waist', 'chest', 'hips', 'thigh', 'arm', 'body_fat', 'muscle_mass');
create type public.consent_type as enum ('terms', 'privacy', 'health_data', 'marketing');
create type public.deletion_request_status as enum ('pending', 'scheduled', 'processing', 'completed', 'cancelled');
create type public.data_export_status as enum ('pending', 'processing', 'ready', 'expired', 'failed');
create type public.idempotency_scope as enum ('payment', 'ai_write', 'booking', 'food_log', 'webhook', 'notification');
create type public.idempotency_status as enum ('pending', 'completed', 'failed');

comment on type public.privacy_visibility is 'Shared privacy levels. coach is used for coach-only/private-by-default progress media and data visibility.';

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'platform_admin';
$$;

revoke all on function public.is_platform_admin() from public;
revoke all on function public.is_platform_admin() from anon;
grant execute on function public.is_platform_admin() to authenticated;
