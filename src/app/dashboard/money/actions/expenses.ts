'use server';

import { redirect } from 'next/navigation';
import {
  assertSaved,
  currentUser,
  dayField,
  numberField,
  read,
  revalidateMoney,
  softDeleteStamp,
} from './shared';

export async function addExpenseAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const category = read(formData, 'category') || 'Fixed';
  const dueDay = dayField(formData, 'due_day');
  if (!name || amount === null) redirect('/dashboard/money/expenses?error=invalid');

  const { error } = await supabase
    .from('money_expenses')
    .insert({ user_id: user.id, name, amount, category, due_day: dueDay });
  assertSaved(error, 'expenses');
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

  const { error } = await supabase
    .from('money_expenses')
    .update({ name, amount, category, due_day: dueDay, active })
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  assertSaved(error, 'expenses');
  revalidateMoney('expenses');
  redirect('/dashboard/money/expenses?saved=1');
}

export async function deleteExpenseAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase
    .from('money_expenses')
    .update(softDeleteStamp())
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  assertSaved(error, 'expenses');
  revalidateMoney('expenses');
  redirect('/dashboard/money/expenses');
}
