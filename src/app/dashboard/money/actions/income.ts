'use server';

import { redirect } from 'next/navigation';
import { currentUser, dayField, numberField, read, revalidateMoney } from './shared';

export async function addIncomeAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const type = read(formData, 'type') || 'fixed';
  const payday = dayField(formData, 'payday');
  if (!name || amount === null) redirect('/dashboard/money/income?error=invalid');

  await supabase.from('money_income').insert({ user_id: user.id, name, amount, type, payday });
  revalidateMoney('income');
  redirect('/dashboard/money/income?saved=1');
}

export async function updateIncomeAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const type = read(formData, 'type') || 'fixed';
  const payday = dayField(formData, 'payday');
  const active = read(formData, 'active') === 'true';
  if (!id || !name || amount === null) redirect('/dashboard/money/income?error=invalid');

  await supabase
    .from('money_income')
    .update({ name, amount, type, payday, active })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('income');
  redirect('/dashboard/money/income?saved=1');
}

export async function deleteIncomeAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_income').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('income');
  redirect('/dashboard/money/income');
}
