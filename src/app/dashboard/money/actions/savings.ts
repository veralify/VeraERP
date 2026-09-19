'use server';

import { redirect } from 'next/navigation';
import { currentUser, numberField, read, revalidateMoney } from './shared';

export async function addSavingAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount') ?? 0;
  const targetAmount = numberField(formData, 'target_amount') ?? 0;
  const monthlyContribution = numberField(formData, 'monthly_contribution') ?? 0;
  const category = read(formData, 'category') || 'General';
  if (!name) redirect('/dashboard/money/savings?error=invalid');

  await supabase.from('money_savings').insert({
    user_id: user.id,
    name,
    amount,
    target_amount: targetAmount,
    monthly_contribution: monthlyContribution,
    category,
  });
  revalidateMoney('savings');
  redirect('/dashboard/money/savings?saved=1');
}

export async function updateSavingAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount') ?? 0;
  const targetAmount = numberField(formData, 'target_amount') ?? 0;
  const monthlyContribution = numberField(formData, 'monthly_contribution') ?? 0;
  const category = read(formData, 'category') || 'General';
  const active = read(formData, 'active') === 'true';
  if (!id || !name) redirect('/dashboard/money/savings?error=invalid');

  await supabase
    .from('money_savings')
    .update({
      name,
      amount,
      target_amount: targetAmount,
      monthly_contribution: monthlyContribution,
      category,
      active,
    })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('savings');
  redirect('/dashboard/money/savings?saved=1');
}

export async function deleteSavingAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_savings').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('savings');
  redirect('/dashboard/money/savings');
}
