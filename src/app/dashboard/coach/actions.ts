'use server';

import { canActAsCoach, claimCoachInvite } from '@lib/api/coachAccess';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

function numberField(formData: FormData, key: string) {
  const value = Number(read(formData, key));
  return Number.isFinite(value) && value >= 0 ? value : null;
}

async function currentCoach() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');

  if (!(await canActAsCoach(user.id, user.email ?? null))) {
    redirect('/dashboard/coach?error=coach-access');
  }
  return { supabase, user };
}

export async function upsertCoachProfileAction(formData: FormData) {
  const { supabase, user } = await currentCoach();
  const headline = read(formData, 'headline');
  const bio = read(formData, 'bio');
  const specialties = read(formData, 'specialties')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const yearsExperience = numberField(formData, 'yearsExperience');
  const hourlyRate = numberField(formData, 'hourlyRate');
  const currency = (read(formData, 'currency') || 'USD').toUpperCase();
  const location = read(formData, 'location');
  const onlineOnly = read(formData, 'onlineOnly') === 'on';

  if (!headline || !/^[A-Z]{3}$/.test(currency)) {
    redirect('/dashboard/coach?error=invalid-profile');
  }

  const { error } = await supabase.from('coach_profiles').upsert(
    {
      id: user.id,
      headline,
      bio: bio || null,
      specialties,
      years_experience: yearsExperience,
      hourly_rate: hourlyRate,
      currency,
      location: location || null,
      online_only: onlineOnly,
    },
    { onConflict: 'id' },
  );
  if (error) redirect('/dashboard/coach?error=save-profile');

  await claimCoachInvite(user.id, user.email ?? null);

  revalidatePath('/dashboard/coach');
  redirect('/dashboard/coach?saved=profile');
}

export async function createCoachSessionAction(formData: FormData) {
  const { supabase, user } = await currentCoach();
  const title = read(formData, 'title');
  const description = read(formData, 'description');
  const sessionType = read(formData, 'sessionType');
  const scheduledAt = read(formData, 'scheduledAt');
  const durationMinutes = numberField(formData, 'durationMinutes');

  if (
    !title ||
    !scheduledAt ||
    !durationMinutes ||
    durationMinutes <= 0 ||
    !['video', 'audio', 'in_person'].includes(sessionType)
  ) {
    redirect('/dashboard/coach?error=invalid-session');
  }

  const scheduledDate = new Date(scheduledAt);
  if (Number.isNaN(scheduledDate.getTime()) || scheduledDate.getTime() <= Date.now()) {
    redirect('/dashboard/coach?error=invalid-session');
  }

  const { error } = await supabase.from('coach_sessions').insert({
    coach_id: user.id,
    title,
    description: description || null,
    session_type: sessionType as 'video' | 'audio' | 'in_person',
    scheduled_at: scheduledDate.toISOString(),
    duration_minutes: durationMinutes,
    status: 'available',
  });
  if (error) redirect('/dashboard/coach?error=save-session');

  revalidatePath('/dashboard/coach');
  redirect('/dashboard/coach?saved=session');
}
