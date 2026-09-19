'use server';

import { redirect } from 'next/navigation';
import { currentUser, dayField, numberField, read, revalidateMoney } from './shared';

export async function addDebtAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const balance = numberField(formData, 'balance');
  const apr = numberField(formData, 'apr') ?? 0;
  const minimumPayment = numberField(formData, 'minimum_payment') ?? 0;
  const dueDay = dayField(formData, 'due_day');
  const priority = Number(read(formData, 'priority')) || 1;
  if (!name || balance === null) redirect('/dashboard/money/debts?error=invalid');

  await supabase.from('money_debts').insert({
    user_id: user.id,
    name,
    balance,
    apr,
    minimum_payment: minimumPayment,
    due_day: dueDay,
    priority,
  });
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

  await supabase
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
  revalidateMoney('debts');
  redirect('/dashboard/money/debts?saved=1');
}

export async function deleteDebtAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_debts').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('debts');
  redirect('/dashboard/money/debts');
}

export async function updatePlanSettingsAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const targetMonths = Number(read(formData, 'targetMonths')) || 12;
  const startDate = read(formData, 'startDate') || new Date().toISOString().slice(0, 10);

  await supabase.from('money_settings').upsert(
    [
      { user_id: user.id, key: 'targetMonths', value: String(targetMonths) },
      { user_id: user.id, key: 'startDate', value: startDate },
    ],
    { onConflict: 'user_id,key' },
  );
  revalidateMoney('debts');
  redirect('/dashboard/money/debts?saved=plan');
}
