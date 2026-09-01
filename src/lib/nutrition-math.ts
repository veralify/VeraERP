export type Sex = 'female' | 'male';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
export type GoalDirection = 'lose' | 'maintain' | 'gain';

export type TargetInput = {
  sex: Sex;
  ageYears: number;
  heightCm: number;
  weightKg: number;
  activityLevel: ActivityLevel;
  direction: GoalDirection;
};

export type NutritionTargets = {
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
};

const activityFactors: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

const calorieAdjustment: Record<GoalDirection, number> = {
  lose: -500,
  maintain: 0,
  gain: 300,
};

/**
 * Deterministic launch target math. BMR uses Mifflin-St Jeor:
 * men = 10W + 6.25H - 5A + 5; women = 10W + 6.25H - 5A - 161.
 * TDEE = BMR * activity factor. Calories are adjusted by goal direction.
 * Macros use a simple split: protein 30%, fat 25%, carbs 45% of calories.
 */
export function calculateNutritionTargets(input: TargetInput): NutritionTargets {
  const sexOffset = input.sex === 'male' ? 5 : -161;
  const bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * input.ageYears + sexOffset;
  const calories = Math.max(
    1200,
    Math.round(bmr * activityFactors[input.activityLevel] + calorieAdjustment[input.direction]),
  );
  return {
    calories,
    proteinG: Math.round((calories * 0.3) / 4),
    carbsG: Math.round((calories * 0.45) / 4),
    fatG: Math.round((calories * 0.25) / 9),
  };
}

export function scaleNutrition(
  perServing: {
    calories: number;
    protein_g: number;
    carbs_g: number;
    fat_g: number;
    fiber_g: number;
    sugar_g: number;
    sodium_mg: number;
    serving_size: number;
  },
  grams: number,
) {
  const factor = grams / Math.max(perServing.serving_size, 1);
  const round = (value: number) => Math.round(value * factor * 10) / 10;
  return {
    calories: Math.round(perServing.calories * factor),
    protein_g: round(perServing.protein_g),
    carbs_g: round(perServing.carbs_g),
    fat_g: round(perServing.fat_g),
    fiber_g: round(perServing.fiber_g),
    sugar_g: round(perServing.sugar_g),
    sodium_mg: Math.round(perServing.sodium_mg * factor),
  };
}
