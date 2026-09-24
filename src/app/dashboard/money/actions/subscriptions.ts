'use server';

import { redirect } from 'next/navigation';
import { assertSaved, currentUser, numberField, read, revalidateMoney } from './shared';

function cadenceField(formData: FormData) {
  return read(formData, 'cadence') === 'yearly' ? 'yearly' : 'monthly';
}

function optionalDateField(formData: FormData, key: string) {
  const value = read(formData, key);
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

export async function addSubscriptionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const cadence = cadenceField(formData);
  const nextChargeDate = optionalDateField(formData, 'next_charge_date');
  const trialEndsOn = optionalDateField(formData, 'trial_ends_on');
  const category = read(formData, 'category') || 'Subscriptions';
  if (!name || amount === null) redirect('/dashboard/money/subscriptions?error=invalid');

  const { error } = await supabase.from('money_subscriptions').insert({
    user_id: user.id,
    name,
    amount,
    cadence,
    next_charge_date: nextChargeDate,
    trial_ends_on: trialEndsOn,
    category,
  });
  assertSaved(error, 'subscriptions');
  revalidateMoney('subscriptions');
  redirect('/dashboard/money/subscriptions?saved=1');
}

export async function updateSubscriptionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const name = read(formData, 'name');
  const amount = numberField(formData, 'amount');
  const cadence = cadenceField(formData);
  const nextChargeDate = optionalDateField(formData, 'next_charge_date');
  const trialEndsOn = optionalDateField(formData, 'trial_ends_on');
  const category = read(formData, 'category') || 'Subscriptions';
  const active = read(formData, 'active') === 'true';
  if (!id || !name || amount === null) redirect('/dashboard/money/subscriptions?error=invalid');

  const { error } = await supabase
    .from('money_subscriptions')
    .update({
      name,
      amount,
      cadence,
      next_charge_date: nextChargeDate,
      trial_ends_on: trialEndsOn,
      category,
      active,
    })
    .eq('id', id)
    .eq('user_id', user.id);
  assertSaved(error, 'subscriptions');
  revalidateMoney('subscriptions');
  redirect('/dashboard/money/subscriptions?saved=1');
}

export async function deleteSubscriptionAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase
    .from('money_subscriptions')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id);
  assertSaved(error, 'subscriptions');
  revalidateMoney('subscriptions');
  redirect('/dashboard/money/subscriptions');
}
