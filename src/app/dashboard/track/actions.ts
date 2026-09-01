'use server';

import { scaleNutrition } from '@lib/nutrition-math';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

function str(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

function positiveNumber(formData: FormData, key: string, fallback?: number) {
  const value = Number(str(formData, key));
  if (Number.isFinite(value) && value > 0) return value;
  return fallback;
}

function dayBounds(date: string) {
  return { start: `${date}T00:00:00.000Z`, end: `${date}T23:59:59.999Z` };
}

async function currentUser() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/?auth=required');
  return { supabase, user };
}

async function refreshDailySummary(userId: string, date: string) {
  const { supabase } = await currentUser();
  const { start, end } = dayBounds(date);
  const { data: logs } = await supabase
    .from('food_logs')
    .select('id')
    .eq('user_id', userId)
    .gte('logged_at', start)
    .lte('logged_at', end)
    .limit(100);
  const logIds = logs?.map((log) => log.id) ?? [];
  if (logIds.length === 0) {
    await supabase.from('daily_nutrition_summaries').upsert(
      {
        user_id: userId,
        date,
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        fiber_g: 0,
        water_ml: 0,
        meal_count: 0,
      },
      { onConflict: 'user_id,date' },
    );
    return;
  }
  const { data: items } = await supabase
    .from('food_log_items')
    .select('calories, protein_g, carbs_g, fat_g, fiber_g')
    .in('food_log_id', logIds)
    .limit(500);
  const totals = (items ?? []).reduce(
    (sum, item) => ({
      calories: sum.calories + item.calories,
      protein_g: sum.protein_g + item.protein_g,
      carbs_g: sum.carbs_g + item.carbs_g,
      fat_g: sum.fat_g + item.fat_g,
      fiber_g: sum.fiber_g + item.fiber_g,
    }),
    { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, fiber_g: 0 },
  );
  await supabase
    .from('daily_nutrition_summaries')
    .upsert(
      { user_id: userId, date, ...totals, water_ml: 0, meal_count: logIds.length },
      { onConflict: 'user_id,date' },
    );
}

export async function logFoodAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const foodId = str(formData, 'foodId');
  const date = str(formData, 'date') || new Date().toISOString().slice(0, 10);
  const mealType = str(formData, 'mealType') || 'breakfast';
  const quantity = positiveNumber(formData, 'quantity', 1) ?? 1;
  const servingGrams = positiveNumber(formData, 'servingGrams');
  if (!foodId || !servingGrams) redirect(`/dashboard/track?date=${date}&error=invalid-food`);

  const { data: food } = await supabase
    .from('foods')
    .select(
      'id, name, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg, serving_size, serving_unit',
    )
    .eq('id', foodId)
    .maybeSingle();
  if (!food) redirect(`/dashboard/track?date=${date}&error=food-not-found`);

  const { start, end } = dayBounds(date);
  const { data: existingGroup } = await supabase
    .from('meal_groups')
    .select('id')
    .eq('user_id', user.id)
    .eq('meal_type', mealType as 'breakfast')
    .gte('logged_at', start)
    .lte('logged_at', end)
    .limit(1)
    .maybeSingle();

  let mealGroupId = existingGroup?.id;
  if (!mealGroupId) {
    const { data: group, error } = await supabase
      .from('meal_groups')
      .insert({
        user_id: user.id,
        name: mealType[0]?.toUpperCase() + mealType.slice(1),
        meal_type: mealType as 'breakfast',
        logged_at: `${date}T12:00:00.000Z`,
      })
      .select('id')
      .single();
    if (error || !group) redirect(`/dashboard/track?date=${date}&error=meal-group`);
    mealGroupId = group.id;
  }

  const { data: log, error: logError } = await supabase
    .from('food_logs')
    .insert({
      user_id: user.id,
      meal_group_id: mealGroupId,
      source: 'manual',
      logged_at: new Date().toISOString(),
      notes: null,
    })
    .select('id')
    .single();
  if (logError || !log) redirect(`/dashboard/track?date=${date}&error=log`);

  const grams = Math.round(servingGrams * quantity * 10) / 10;
  const nutrition = scaleNutrition(food, grams);
  const { error: itemError } = await supabase.from('food_log_items').insert({
    food_log_id: log.id,
    food_id: food.id,
    name: food.name,
    quantity,
    unit: food.serving_unit,
    grams,
    ai_estimated: false,
    confidence: null,
    ...nutrition,
  });
  if (itemError) redirect(`/dashboard/track?date=${date}&error=item`);

  await refreshDailySummary(user.id, date);
  revalidatePath('/dashboard');
  revalidatePath('/dashboard/track');
  redirect(`/dashboard/track?date=${date}`);
}

export async function updateFoodItemAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const itemId = str(formData, 'itemId');
  const date = str(formData, 'date') || new Date().toISOString().slice(0, 10);
  const quantity = positiveNumber(formData, 'quantity');
  if (!itemId || !quantity) redirect(`/dashboard/track?date=${date}&error=invalid-edit`);
  const { data: item } = await supabase
    .from('food_log_items')
    .select(
      'id, quantity, grams, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg, food_logs!inner(user_id)',
    )
    .eq('id', itemId)
    .eq('food_logs.user_id', user.id)
    .maybeSingle();
  if (!item) redirect(`/dashboard/track?date=${date}&error=item-not-found`);
  const factor = quantity / Math.max(item.quantity, 0.01);
  const round = (value: number) => Math.round(value * factor * 10) / 10;
  await supabase
    .from('food_log_items')
    .update({
      quantity,
      grams: item.grams ? round(item.grams) : item.grams,
      calories: Math.round(item.calories * factor),
      protein_g: round(item.protein_g),
      carbs_g: round(item.carbs_g),
      fat_g: round(item.fat_g),
      fiber_g: round(item.fiber_g),
      sugar_g: round(item.sugar_g),
      sodium_mg: Math.round(item.sodium_mg * factor),
    })
    .eq('id', itemId);
  await refreshDailySummary(user.id, date);
  revalidatePath('/dashboard/track');
  redirect(`/dashboard/track?date=${date}`);
}

export async function deleteFoodItemAction(formData: FormData) {
  const { supabase, user } = await currentUser();
  const itemId = str(formData, 'itemId');
  const logId = str(formData, 'logId');
  const date = str(formData, 'date') || new Date().toISOString().slice(0, 10);
  if (!itemId) redirect(`/dashboard/track?date=${date}&error=invalid-delete`);
  await supabase.from('food_log_items').delete().eq('id', itemId);
  if (logId) {
    const { count } = await supabase
      .from('food_log_items')
      .select('id', { count: 'exact', head: true })
      .eq('food_log_id', logId);
    if (count === 0)
      await supabase.from('food_logs').delete().eq('id', logId).eq('user_id', user.id);
  }
  await refreshDailySummary(user.id, date);
  revalidatePath('/dashboard/track');
  redirect(`/dashboard/track?date=${date}`);
}
