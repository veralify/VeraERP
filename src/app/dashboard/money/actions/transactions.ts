'use server';

import { redirect } from 'next/navigation';
import {
  assertSaved,
  currentUser,
  dateField,
  numberField,
  read,
  revalidateMoney,
  softDeleteStamp,
} from './shared';

/**
 * Category, scope and currency as the phone and the accounting sync expect
 * them: a category key (contract §3), `personal`/`business`, and an ISO
 * currency code. Returns null when a field is malformed.
 */
function classification(formData: FormData) {
  const category = read(formData, 'category') || 'other';
  const scope = read(formData, 'scope') === 'business' ? 'business' : 'personal';
  const currency = read(formData, 'currency').toUpperCase();
  // Old rows can hold free-text categories; editing one keeps its value, so
  // only its length is bounded here rather than the key pattern.
  if (category.length > 80 || !/^[A-Z]{3}$/.test(currency)) return null;
  return { category, scope, currency } as const;
}

export async function addTransactionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const merchant = read(formData, 'merchant');
  const amount = numberField(formData, 'amount');
  const direction = read(formData, 'direction') === 'income' ? 'income' : 'expense';
  const transactionDate = dateField(formData, 'transaction_date');
  const fields = classification(formData);
  const account = read(formData, 'account') || 'Main account';
  const notes = read(formData, 'notes');
  if (!merchant || amount === null || !transactionDate || !fields)
    redirect('/dashboard/money/transactions?error=invalid');

  const { error } = await supabase.from('money_transactions').insert({
    user_id: user.id,
    merchant,
    amount,
    direction,
    transaction_date: transactionDate,
    ...fields,
    account,
    notes,
  });
  assertSaved(error, 'transactions');
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
  const fields = classification(formData);
  const account = read(formData, 'account') || 'Main account';
  const notes = read(formData, 'notes');
  if (!id || !merchant || amount === null || !transactionDate || !fields)
    redirect('/dashboard/money/transactions?error=invalid');

  // A converted amount is only true for the amount, currency and date it was
  // converted from; if any of those change, drop it so the dashboard doesn't
  // show a stale home-currency figure (the FX job fills it again).
  const { data: current } = await supabase
    .from('money_transactions')
    .select('amount, currency, transaction_date, home_amount')
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null)
    .maybeSingle();
  const conversionStale =
    current !== null &&
    current.home_amount !== null &&
    (Number(current.amount) !== amount ||
      current.currency !== fields.currency ||
      current.transaction_date !== transactionDate);

  const { error } = await supabase
    .from('money_transactions')
    .update({
      merchant,
      amount,
      direction,
      transaction_date: transactionDate,
      ...fields,
      ...(conversionStale ? { home_amount: null } : {}),
      account,
      notes,
    })
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  assertSaved(error, 'transactions');
  revalidateMoney('transactions');
  redirect('/dashboard/money/transactions?saved=1');
}

export async function deleteTransactionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase
    .from('money_transactions')
    .update(softDeleteStamp())
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  assertSaved(error, 'transactions');
  revalidateMoney('transactions');
  redirect('/dashboard/money/transactions');
}
