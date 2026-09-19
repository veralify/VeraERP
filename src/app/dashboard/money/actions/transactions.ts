'use server';

import { redirect } from 'next/navigation';
import { currentUser, dateField, numberField, read, revalidateMoney } from './shared';

export async function addTransactionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const merchant = read(formData, 'merchant');
  const amount = numberField(formData, 'amount');
  const direction = read(formData, 'direction') === 'income' ? 'income' : 'expense';
  const transactionDate = dateField(formData, 'transaction_date');
  const category = read(formData, 'category') || 'Uncategorized';
  const account = read(formData, 'account') || 'Main account';
  const notes = read(formData, 'notes');
  if (!merchant || amount === null || !transactionDate)
    redirect('/dashboard/money/transactions?error=invalid');

  await supabase.from('money_transactions').insert({
    user_id: user.id,
    merchant,
    amount,
    direction,
    transaction_date: transactionDate,
    category,
    account,
    notes,
  });
  revalidateMoney('transactions');
  redirect('/dashboard/money/transactions?saved=1');
}

export async function updateTransactionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const merchant = read(formData, 'merchant');
  const amount = numberField(formData, 'amount');
  const direction = read(formData, 'direction') === 'income' ? 'income' : 'expense';
  const transactionDate = dateField(formData, 'transaction_date');
  const category = read(formData, 'category') || 'Uncategorized';
  const account = read(formData, 'account') || 'Main account';
  const notes = read(formData, 'notes');
  if (!id || !merchant || amount === null || !transactionDate)
    redirect('/dashboard/money/transactions?error=invalid');

  await supabase
    .from('money_transactions')
    .update({
      merchant,
      amount,
      direction,
      transaction_date: transactionDate,
      category,
      account,
      notes,
    })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('transactions');
  redirect('/dashboard/money/transactions?saved=1');
}

export async function deleteTransactionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_transactions').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('transactions');
  redirect('/dashboard/money/transactions');
}
