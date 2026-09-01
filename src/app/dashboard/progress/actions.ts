'use server';

import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

export async function addWeightEntryAction(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  const weightKg = Number(read(formData, 'weightKg'));
  const measuredAt = read(formData, 'measuredAt');
  const notes = read(formData, 'notes') || null;
  if (!Number.isFinite(weightKg) || weightKg < 30 || weightKg > 300)
    redirect('/dashboard/progress?error=invalid-weight');
  const timestamp = measuredAt
    ? new Date(`${measuredAt}T12:00:00.000Z`).toISOString()
    : new Date().toISOString();
  const { error } = await supabase.from('weight_entries').insert({
    user_id: user.id,
    weight_kg: weightKg,
    measured_at: timestamp,
    source: 'manual',
    notes,
  });
  if (error) redirect('/dashboard/progress?error=create');
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/progress');
  redirect('/dashboard/progress');
}
