'use server';

import {
  type ActivityLevel,
  calculateNutritionTargets,
  type GoalDirection,
  type Sex,
} from '@lib/nutrition-math';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

function read(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

function numberField(formData: FormData, key: string) {
  const value = Number(read(formData, key));
  return Number.isFinite(value) && value > 0 ? value : null;
}

async function currentUser() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  return { supabase, user };
}

export async function createGoalAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const title = read(formData, 'title');
  const direction = read(formData, 'direction') as GoalDirection;
  const sex = read(formData, 'sex') as Sex;
  const activityLevel = read(formData, 'activityLevel') as ActivityLevel;
  const ageYears = numberField(formData, 'ageYears');
  const heightCm = numberField(formData, 'heightCm');
  const currentWeightKg = numberField(formData, 'currentWeightKg');
  const targetWeightKg = numberField(formData, 'targetWeightKg');
  const targetDate = read(formData, 'targetDate') || null;

  if (
    !title ||
    !ageYears ||
    !heightCm ||
    !currentWeightKg ||
    !targetWeightKg ||
    !['lose', 'maintain', 'gain'].includes(direction) ||
    !['female', 'male'].includes(sex) ||
    !['sedentary', 'light', 'moderate', 'active', 'very_active'].includes(activityLevel)
  ) {
    redirect('/dashboard/goals?error=invalid');
  }

  const targets = calculateNutritionTargets({
    sex,
    ageYears,
    heightCm,
    weightKg: currentWeightKg,
    activityLevel,
    direction,
  });
  const { data: goal, error } = await supabase
    .from('goals')
    .insert({
      user_id: user.id,
      title,
      type: direction === 'maintain' ? 'maintenance' : `weight_${direction}`,
      starting_value: currentWeightKg,
      target_value: targetWeightKg,
      unit: 'kg',
      start_date: new Date().toISOString().slice(0, 10),
      target_date: targetDate,
      status: 'active',
    })
    .select('id')
    .single();
  if (error || !goal) redirect('/dashboard/goals?error=create');

  await supabase.from('goal_targets').insert([
    {
      goal_id: goal.id,
      metric: 'calories',
      target_value: targets.calories,
      unit: 'kcal',
      period: 'daily',
    },
    {
      goal_id: goal.id,
      metric: 'protein_g',
      target_value: targets.proteinG,
      unit: 'g',
      period: 'daily',
    },
    {
      goal_id: goal.id,
      metric: 'carbs_g',
      target_value: targets.carbsG,
      unit: 'g',
      period: 'daily',
    },
    { goal_id: goal.id, metric: 'fat_g', target_value: targets.fatG, unit: 'g', period: 'daily' },
  ]);
  await supabase
    .from('profiles')
    .update({ height_cm: heightCm, activity_level: activityLevel, onboarding_completed: true })
    .eq('id', user.id);
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/goals');
  redirect('/dashboard/goals');
}

export async function updateGoalAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const goalId = read(formData, 'goalId');
  const title = read(formData, 'title');
  const status = read(formData, 'status') as 'active' | 'paused' | 'completed' | 'cancelled';
  const targetValue = numberField(formData, 'targetValue');
  if (!goalId || !title || !['active', 'paused', 'completed', 'cancelled'].includes(status))
    redirect('/dashboard/goals?error=invalid-edit');
  await supabase
    .from('goals')
    .update({ title, status, target_value: targetValue })
    .eq('id', goalId)
    .eq('user_id', user.id);
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/goals');
  redirect('/dashboard/goals');
}
