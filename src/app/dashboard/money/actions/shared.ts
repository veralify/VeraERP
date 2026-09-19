import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

/**
 * Plain helpers shared by every `actions/<domain>.ts` file. No `'use server'`
 * directive here — a file with that directive requires every exported
 * binding to be an async Server Action, which these sync validators aren't.
 */

export function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

export function numberField(formData: FormData, key: string) {
  const value = Number(read(formData, key));
  return Number.isFinite(value) && value >= 0 ? value : null;
}

export function dayField(formData: FormData, key: string) {
  const value = Number(read(formData, key));
  return Number.isFinite(value) && value >= 1 && value <= 31 ? value : null;
}

/** Validates a plain `YYYY-MM-DD` date input; returns null for empty/invalid. */
export function dateField(formData: FormData, key: string) {
  const value = read(formData, key);
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

export async function currentUser() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  return { supabase, user };
}

/** Revalidates both the domain sub-page and the shared Overview page. */
export function revalidateMoney(domain: string) {
  revalidatePath('/dashboard/money');
  revalidatePath(`/dashboard/money/${domain}`);
}
