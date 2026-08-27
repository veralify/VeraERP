// @ts-nocheck
import { GatewayError } from './types.ts';

export type NutrientSnapshot = {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g?: number;
  sodium_mg?: number;
  micros?: Record<string, number>;
};
export type CanonicalFood = {
  id: string;
  name: string;
  serving_size: number;
  serving_unit: string;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g?: number;
  sodium_mg?: number;
};
export type FoodNutritionVersion = {
  id: string;
  food_id: string;
  version: number;
  nutrition: unknown;
};
export type FoodServing = { id: string; food_id: string; label: string; grams: number };
export type PortionInput = { quantity: number; unit: string; grams?: number | null };
export type ResolvedFoodForNutrition = {
  food: CanonicalFood;
  nutritionVersion: FoodNutritionVersion;
  servings: FoodServing[];
};
export type NutritionEngineResult = NutrientSnapshot & {
  grams: number;
  food_id: string;
  food_nutrition_version_id: string;
  basis: 'per_100g' | 'per_serving';
};

const ROUND = { calories: 0, grams: 1, macro: 1, sodium: 0 };
const norm = (s: string) => s.trim().toLowerCase().replace(/\s+/g, '_');
const round = (value: number, places: number) => {
  const factor = 10 ** places;
  return Math.round((value + Number.EPSILON) * factor) / factor;
};
const numberOr = (v: unknown, fallback = 0) => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);
const nutritionObject = (version: FoodNutritionVersion, food: CanonicalFood) => {
  const n = version.nutrition && typeof version.nutrition === 'object' ? version.nutrition as Record<string, unknown> : {};
  const per100 = n.per_100g && typeof n.per_100g === 'object' ? n.per_100g as Record<string, unknown> : null;
  if (per100) return { basis: 'per_100g' as const, grams: 100, n: per100 };
  const basisGrams = numberOr(n.serving_size, food.serving_size);
  return { basis: 'per_serving' as const, grams: basisGrams, n: { ...food, ...n } };
};
export function portionToGrams(portion: PortionInput, resolved: ResolvedFoodForNutrition): number {
  const quantity = numberOr(portion.quantity, NaN);
  if (!Number.isFinite(quantity) || quantity < 0) throw new GatewayError('BAD_REQUEST', 'Portion quantity must be a non-negative number.', 400);
  if (typeof portion.grams === 'number') {
    if (portion.grams < 0) throw new GatewayError('BAD_REQUEST', 'Portion grams must be non-negative.', 400);
    return round(portion.grams, ROUND.grams);
  }
  const unit = norm(portion.unit);
  if (['g', 'gram', 'grams'].includes(unit)) return round(quantity, ROUND.grams);
  if (['ml', 'milliliter', 'milliliters'].includes(unit)) {
    if (norm(resolved.food.serving_unit) === 'ml') return round(quantity, ROUND.grams);
    const serving = resolved.servings.find((s) => ['ml', 'milliliter', 'milliliters'].includes(norm(s.label)) || norm(s.label) === `${quantity}_ml`);
    if (serving) return round(quantity * serving.grams, ROUND.grams);
    throw new GatewayError('BAD_REQUEST', 'Cannot convert ml without a matching food serving/density.', 400);
  }
  const serving = resolved.servings.find((s) => norm(s.label) === unit || `${norm(s.label)}s` === unit || norm(s.label).replace(/s$/, '') === unit.replace(/s$/, ''));
  if (serving) return round(quantity * serving.grams, ROUND.grams);
  if (['serving', 'servings'].includes(unit)) return round(quantity * resolved.food.serving_size, ROUND.grams);
  throw new GatewayError('BAD_REQUEST', `No serving conversion for unit: ${portion.unit}`, 400);
}
export function calculateNutrition(resolved: ResolvedFoodForNutrition, portion: PortionInput): NutritionEngineResult {
  const grams = portionToGrams(portion, resolved);
  const source = nutritionObject(resolved.nutritionVersion, resolved.food);
  if (source.grams <= 0) throw new GatewayError('INTERNAL_ERROR', 'Canonical nutrition basis grams must be positive.', 500);
  if (grams === 0) return { food_id: resolved.food.id, food_nutrition_version_id: resolved.nutritionVersion.id, basis: source.basis, grams: 0, calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, fiber_g: 0, sugar_g: 0, sodium_mg: 0 };
  const factor = grams / source.grams;
  const calc = (key: string, places = ROUND.macro) => round(numberOr(source.n[key], 0) * factor, places);
  return {
    food_id: resolved.food.id,
    food_nutrition_version_id: resolved.nutritionVersion.id,
    basis: source.basis,
    grams,
    calories: calc('calories', ROUND.calories),
    protein_g: calc('protein_g'),
    carbs_g: calc('carbs_g'),
    fat_g: calc('fat_g'),
    fiber_g: calc('fiber_g'),
    sugar_g: calc('sugar_g'),
    sodium_mg: calc('sodium_mg', ROUND.sodium),
    micros: source.n.micros && typeof source.n.micros === 'object'
      ? Object.fromEntries(Object.entries(source.n.micros as Record<string, number>).map(([k, v]) => [k, round(numberOr(v) * factor, ROUND.macro)]))
      : undefined,
  };
}
