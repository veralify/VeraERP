'use server';

import { redirect } from 'next/navigation';
import { assertSaved, currentUser, read, revalidateMoney } from './shared';

function optionalDateField(formData: FormData, key: string) {
  const value = read(formData, key);
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

export async function addDocumentAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const title = read(formData, 'title');
  const documentType = read(formData, 'document_type') || 'Receipt';
  const expiryDate = optionalDateField(formData, 'expiry_date');
  const notes = read(formData, 'notes');
  if (!title) redirect('/dashboard/money/documents?error=invalid');

  const { error } = await supabase.from('money_documents').insert({
    user_id: user.id,
    title,
    document_type: documentType,
    expiry_date: expiryDate,
    notes,
  });
  assertSaved(error, 'documents');
  revalidateMoney('documents');
  redirect('/dashboard/money/documents?saved=1');
}

export async function updateDocumentAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const title = read(formData, 'title');
  const documentType = read(formData, 'document_type') || 'Receipt';
  const expiryDate = optionalDateField(formData, 'expiry_date');
  const notes = read(formData, 'notes');
  if (!id || !title) redirect('/dashboard/money/documents?error=invalid');

  const { error } = await supabase
    .from('money_documents')
    .update({ title, document_type: documentType, expiry_date: expiryDate, notes })
    .eq('id', id)
    .eq('user_id', user.id);
  assertSaved(error, 'documents');
  revalidateMoney('documents');
  redirect('/dashboard/money/documents?saved=1');
}

export async function deleteDocumentAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const id = read(formData, 'id');
  const { error } = await supabase
    .from('money_documents')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id);
  assertSaved(error, 'documents');
  revalidateMoney('documents');
  redirect('/dashboard/money/documents');
}
