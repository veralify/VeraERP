'use server';

import { randomUUID } from 'node:crypto';
import { isMonth } from '@lib/money/spending';
import { redirect } from 'next/navigation';
import { currentUser, numberField, read, revalidateMoney, softDeleteStamp } from './shared';

/**
 * Budgets are the one thing the web edits that the phone also edits
 * (money_budgets ↔ CategoryBudget). The id is minted here, the same way the
 * phone mints its own, and deletes are soft so they reach the phone.
 */

function budgetsPath(formData: FormData, query: string) {
  const month = read(formData, 'month');
  return `/dashboard/money/budgets?${query}${isMonth(month) ? `&month=${month}` : ''}`;
}

function fields(formData: FormData) {
  const limit = numberField(formData, 'monthly_limit');
  const currency = read(formData, 'currency').toUpperCase();
  if (limit === null || limit <= 0 || !/^[A-Z]{3}$/.test(currency)) return null;
  // numeric on the server; keep cents, not float noise.
  return { monthly_limit: Math.round(limit * 100) / 100, currency };
}

export async function addBudgetAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const categoryKey = read(formData, 'category');
  const values = fields(formData);
  if (!/^[a-z0-9_]{1,40}$/.test(categoryKey) || !values)
    redirect(budgetsPath(formData, 'error=invalid'));

  // One live budget per category (a partial unique index backs this up; the
  // check here turns the common case into a friendly message).
  const { data: existing } = await supabase
    .from('money_budgets')
    .select('id')
    .eq('user_id', user.id)
    .eq('category_key', categoryKey)
    .is('deleted_at', null)
    .maybeSingle();
  if (existing) redirect(budgetsPath(formData, 'error=duplicate'));

  const { error } = await supabase.from('money_budgets').insert({
    id: randomUUID(),
    user_id: user.id,
    category_key: categoryKey,
    ...values,
  });
  if (error) {
    redirect(budgetsPath(formData, error.code === '23505' ? 'error=duplicate' : 'error=save'));
  }
  revalidateMoney('budgets');
  redirect(budgetsPath(formData, 'saved=1'));
}

export async function updateBudgetAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const values = fields(formData);
  if (!id || !values) redirect(budgetsPath(formData, 'error=invalid'));

  const { error } = await supabase
    .from('money_budgets')
    .update(values)
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  if (error) redirect(budgetsPath(formData, 'error=save'));
  revalidateMoney('budgets');
  redirect(budgetsPath(formData, 'saved=1'));
}

export async function deleteBudgetAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase
    .from('money_budgets')
    .update(softDeleteStamp())
    .eq('id', id)
    .eq('user_id', user.id)
    .is('deleted_at', null);
  if (error) redirect(budgetsPath(formData, 'error=save'));
  revalidateMoney('budgets');
  redirect(budgetsPath(formData, 'removed=1'));
}
