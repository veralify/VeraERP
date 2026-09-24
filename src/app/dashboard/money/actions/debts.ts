'use server';

import { redirect } from 'next/navigation';
import {
  assertSaved,
  currentUser,
  dateField,
  dayField,
  numberField,
  read,
  revalidateMoney,
} from './shared';

export async function addDebtAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const balance = numberField(formData, 'balance');
  const apr = numberField(formData, 'apr') ?? 0;
  const minimumPayment = numberField(formData, 'minimum_payment') ?? 0;
  const dueDay = dayField(formData, 'due_day');
  const priority = Number(read(formData, 'priority')) || 1;
  if (!name || balance === null) redirect('/dashboard/money/debts?error=invalid');

  const { error } = await supabase.from('money_debts').insert({
    user_id: user.id,
    name,
    balance,
    apr,
    minimum_payment: minimumPayment,
    due_day: dueDay,
    priority,
  });
  assertSaved(error, 'debts');
  revalidateMoney('debts');
  redirect('/dashboard/money/debts?saved=1');
}

export async function updateDebtAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const name = read(formData, 'name');
  const balance = numberField(formData, 'balance');
  const apr = numberField(formData, 'apr') ?? 0;
  const minimumPayment = numberField(formData, 'minimum_payment') ?? 0;
  const dueDay = dayField(formData, 'due_day');
  const priority = Number(read(formData, 'priority')) || 1;
  if (!id || !name || balance === null) redirect('/dashboard/money/debts?error=invalid');

  const { error } = await supabase
    .from('money_debts')
    .update({
      name,
      balance,
      apr,
      minimum_payment: minimumPayment,
      due_day: dueDay,
      priority,
    })
    .eq('id', id)
    .eq('user_id', user.id);
  assertSaved(error, 'debts');
  revalidateMoney('debts');
  redirect('/dashboard/money/debts?saved=1');
}

export async function deleteDebtAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase.from('money_debts').delete().eq('id', id).eq('user_id', user.id);
  assertSaved(error, 'debts');
  revalidateMoney('debts');
  redirect('/dashboard/money/debts');
}

export async function updatePlanSettingsAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  // The payoff table renders one row per month and `new Date(startDate)` must be valid,
  // so clamp the horizon and reject malformed dates instead of storing them.
  const months = Math.trunc(Number(read(formData, 'targetMonths')));
  const targetMonths = Number.isFinite(months) && months >= 1 ? Math.min(months, 120) : 12;
  const startDate = dateField(formData, 'startDate') ?? new Date().toISOString().slice(0, 10);

  const { error } = await supabase.from('money_settings').upsert(
    [
      { user_id: user.id, key: 'targetMonths', value: String(targetMonths) },
      { user_id: user.id, key: 'startDate', value: startDate },
    ],
    { onConflict: 'user_id,key' },
  );
  assertSaved(error, 'debts');
  revalidateMoney('debts');
  redirect('/dashboard/money/debts?saved=plan');
}
