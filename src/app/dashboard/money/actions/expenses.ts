'use server';

import { redirect } from 'next/navigation';
import { currentUser, dayField, numberField, read, revalidateMoney } from './shared';

export async function addExpenseAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const category = read(formData, 'category') || 'Fixed';
  const dueDay = dayField(formData, 'due_day');
  if (!name || amount === null) redirect('/dashboard/money/expenses?error=invalid');

  await supabase
    .from('money_expenses')
    .insert({ user_id: user.id, name, amount, category, due_day: dueDay });
  revalidateMoney('expenses');
  redirect('/dashboard/money/expenses?saved=1');
}

export async function updateExpenseAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const category = read(formData, 'category') || 'Fixed';
  const dueDay = dayField(formData, 'due_day');
  const active = read(formData, 'active') === 'true';
  if (!id || !name || amount === null) redirect('/dashboard/money/expenses?error=invalid');

  await supabase
    .from('money_expenses')
    .update({ name, amount, category, due_day: dueDay, active })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('expenses');
  redirect('/dashboard/money/expenses?saved=1');
}

export async function deleteExpenseAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_expenses').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('expenses');
  redirect('/dashboard/money/expenses');
}
