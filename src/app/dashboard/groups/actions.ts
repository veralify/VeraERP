'use server';

import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

async function currentUser() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  return { supabase, user };
}

export async function joinGroupAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const groupId = read(formData, 'groupId');
  const slug = read(formData, 'slug');
  if (!groupId) redirect('/dashboard/groups?error=invalid-group');
  await supabase
    .from('group_members')
    .upsert({ group_id: groupId, user_id: user.id, role: 'member', status: 'active' });
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/groups');
  if (slug) revalidatePath(`/dashboard/groups/${slug}`);
  redirect(slug ? `/dashboard/groups/${slug}` : '/dashboard/groups');
}

export async function leaveGroupAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const groupId = read(formData, 'groupId');
  const slug = read(formData, 'slug');
  if (!groupId) redirect('/dashboard/groups?error=invalid-group');
  await supabase.from('group_members').delete().eq('group_id', groupId).eq('user_id', user.id);
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/groups');
  if (slug) revalidatePath(`/dashboard/groups/${slug}`);
  redirect(slug ? `/dashboard/groups/${slug}` : '/dashboard/groups');
}

export async function createGroupPostAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const groupId = read(formData, 'groupId');
  const slug = read(formData, 'slug');
  const content = read(formData, 'content');
  if (!groupId || !slug || content.length < 1 || content.length > 1000)
    redirect(
      slug
        ? `/dashboard/groups/${slug}?error=invalid-post`
        : '/dashboard/groups?error=invalid-post',
    );
  const { error } = await supabase.from('posts').insert({
    author_id: user.id,
    group_id: groupId,
    content,
    post_type: 'text',
    visibility: 'group',
    status: 'published',
  });
  if (error) redirect(`/dashboard/groups/${slug}?error=post`);
  revalidatePath(`/dashboard/groups/${slug}`);
  redirect(`/dashboard/groups/${slug}`);
}
