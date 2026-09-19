'use server';

import { redirect } from 'next/navigation';
import { currentUser, read, revalidateMoney } from './shared';

function optionalDateField(formData: FormData, key: string) {
  const value = read(formData, key);
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

export async function addAdminTaskAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const title = read(formData, 'title');
  const category = read(formData, 'category') || 'General';
  const dueDate = optionalDateField(formData, 'due_date');
  const notes = read(formData, 'notes');
  if (!title) redirect('/dashboard/money/admin-tasks?error=invalid');

  await supabase.from('money_admin_tasks').insert({
    user_id: user.id,
    title,
    category,
    due_date: dueDate,
    notes,
  });
  revalidateMoney('admin-tasks');
  redirect('/dashboard/money/admin-tasks?saved=1');
}

export async function updateAdminTaskAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const title = read(formData, 'title');
  const category = read(formData, 'category') || 'General';
  const dueDate = optionalDateField(formData, 'due_date');
  const notes = read(formData, 'notes');
  const status = read(formData, 'status') === 'done' ? 'done' : 'open';
  if (!id || !title) redirect('/dashboard/money/admin-tasks?error=invalid');

  await supabase
    .from('money_admin_tasks')
    .update({ title, category, due_date: dueDate, notes, status })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('admin-tasks');
  redirect('/dashboard/money/admin-tasks?saved=1');
}

export async function toggleAdminTaskStatusAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const nextStatus = read(formData, 'status') === 'done' ? 'done' : 'open';
  await supabase
    .from('money_admin_tasks')
    .update({ status: nextStatus })
    .eq('id', id)
    .eq('user_id', user.id);
  revalidateMoney('admin-tasks');
  redirect('/dashboard/money/admin-tasks');
}

export async function deleteAdminTaskAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  await supabase.from('money_admin_tasks').delete().eq('id', id).eq('user_id', user.id);
  revalidateMoney('admin-tasks');
  redirect('/dashboard/money/admin-tasks');
}
