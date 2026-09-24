'use server';

import { createSupabaseServerClient } from '@lib/supabase/server';
import type { SupabaseClient } from '@supabase/supabase-js';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import {
  type DistanceUnit,
  mileageAmount,
  presetById,
  toMiles,
  ukTaxYearStart,
} from './_lib/mileage';

const PAGE = '/dashboard/money/mileage';

function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

/** A finite number ≥ 0 (or > 0 with `positive`), or null. Empty is null, not 0. */
function numberField(formData: FormData, key: string, positive = false) {
  const raw = read(formData, key).replace(',', '.');
  if (!raw) return null;
  const value = Number(raw);
  if (!Number.isFinite(value)) return null;
  return positive ? (value > 0 ? value : null) : value >= 0 ? value : null;
}

async function signedIn() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  // Untyped: the mileage RPCs and the receipts-era columns may not be in the
  // generated Database types yet.
  return { client: supabase as unknown as SupabaseClient, user };
}

/**
 * Business miles already logged in the trip's UK tax year, up to and
 * including its date. Only needed for the banded (UK car) rate.
 */
async function priorBusinessMiles(client: SupabaseClient, userId: string, tripDate: string) {
  const { data, error } = await client
    .from('money_mileage_trips')
    .select('distance, unit')
    .eq('user_id', userId)
    .eq('scope', 'business')
    .is('deleted_at', null)
    .gte('trip_date', ukTaxYearStart(tripDate))
    .lte('trip_date', tripDate);
  if (error) redirect(`${PAGE}?error=save`);
  return ((data ?? []) as { distance: number | string; unit: DistanceUnit }[]).reduce(
    (sum, trip) => sum + toMiles(Number(trip.distance), trip.unit),
    0,
  );
}

export async function logTripAction(formData: FormData) {
  const { client, user } = await signedIn();
  const preset = presetById(read(formData, 'preset'));
  const tripDate = read(formData, 'trip_date');
  const distance = numberField(formData, 'distance', true);
  const unit: DistanceUnit = read(formData, 'unit') === 'mi' ? 'mi' : 'km';
  const rate = numberField(formData, 'rate');
  const rateAfter = preset.band ? numberField(formData, 'rate_after') : null;
  const currency = read(formData, 'currency').toUpperCase();
  const scope = read(formData, 'scope') === 'personal' ? 'personal' : 'business';
  const back = `${PAGE}?preset=${preset.id}`;

  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(tripDate) ||
    distance === null ||
    rate === null ||
    (preset.band && rateAfter === null) ||
    !/^[A-Z]{3}$/.test(currency)
  ) {
    redirect(`${back}&error=invalid`);
  }

  const band =
    preset.band && rateAfter !== null ? { limitMiles: preset.band.limitMiles, rateAfter } : null;
  const prior =
    band && scope === 'business' ? await priorBusinessMiles(client, user.id, tripDate) : 0;
  const { amount, effectiveRate } = mileageAmount({
    distance,
    unit,
    rate,
    band,
    priorBusinessMiles: prior,
    business: scope === 'business',
  });

  const { error } = await client.rpc('money_log_mileage_trip', {
    p_trip_date: tripDate,
    p_distance: distance,
    p_unit: unit,
    p_rate_per_unit: effectiveRate,
    p_amount: amount,
    p_currency: currency,
    p_origin: read(formData, 'origin').slice(0, 200),
    p_destination: read(formData, 'destination').slice(0, 200),
    p_purpose: read(formData, 'purpose').slice(0, 500),
    p_scope: scope,
  });
  if (error) redirect(`${back}&error=save`);

  revalidatePath(PAGE);
  revalidatePath('/dashboard/money');
  revalidatePath('/dashboard/money/transactions');
  redirect(`${back}&saved=1`);
}

export async function deleteTripAction(formData: FormData) {
  const { client } = await signedIn();
  const id = read(formData, 'id');
  const { error } = await client.rpc('money_delete_mileage_trip', { p_id: id });
  if (error) redirect(`${PAGE}?error=save`);
  revalidatePath(PAGE);
  revalidatePath('/dashboard/money');
  revalidatePath('/dashboard/money/transactions');
  redirect(PAGE);
}
