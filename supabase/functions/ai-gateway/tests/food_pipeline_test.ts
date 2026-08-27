// @ts-nocheck
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { calculateNutrition } from '../nutrition-engine.ts';
import { resolveFoodCandidate } from '../provenance.ts';
import { buildAnalyzeFoodResponse, thresholdDecision } from '../food-pipeline.ts';
import { loadModelPolicy } from '../registry.ts';
import { GatewayError } from '../types.ts';

const food = { id: 'food-chicken', name: 'Chicken Breast', source: 'usda', external_id: '171077', barcode: '0123', serving_size: 100, serving_unit: 'g', calories: 165, protein_g: 31, carbs_g: 0, fat_g: 3.6, fiber_g: 0, sugar_g: 0, sodium_mg: 74 };
const version = { id: 'ver-1', food_id: food.id, version: 1, nutrition: { per_100g: { calories: 165, protein_g: 31, carbs_g: 0, fat_g: 3.6, fiber_g: 0, sugar_g: 0, sodium_mg: 74 } } };
const servings = [{ id: 'serv-1', food_id: food.id, label: 'piece', grams: 120 }, { id: 'serv-2', food_id: food.id, label: 'serving', grams: 100 }];
const source = { id: 'src-usda', code: 'usda', priority: 1, is_active: true };
const mapping = { id: 'map-1', food_id: food.id, food_source_id: source.id, external_id: food.external_id };
function db() {
  const tables = { foods: [food], food_nutrition_versions: [version], food_servings: servings, food_sources: [source], food_external_mappings: [mapping] };
  return { from(table: string) { let rows = [...(tables[table] ?? [])]; const q: any = { select: () => q, eq: (col: string, val: unknown) => { rows = rows.filter((r) => r[col] === val); return q; }, order: (col: string, opts: any) => { rows.sort((a,b) => opts?.ascending === false ? Number(b[col])-Number(a[col]) : Number(a[col])-Number(b[col])); return q; }, limit: (n: number) => { rows = rows.slice(0,n); return Promise.resolve({ data: rows, error: null }); }, maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }), then: (resolve: any) => resolve({ data: rows, error: null }) }; return q; } };
}
const resolved = { food, nutritionVersion: version, servings };
Deno.test('nutrition engine per-100g grams math and rounding', () => {
  assertEquals(calculateNutrition(resolved, { quantity: 150, unit: 'g' }), { food_id: food.id, food_nutrition_version_id: version.id, basis: 'per_100g', grams: 150, calories: 248, protein_g: 46.5, carbs_g: 0, fat_g: 5.4, fiber_g: 0, sugar_g: 0, sodium_mg: 111, micros: undefined });
});
Deno.test('nutrition engine serving and piece conversions', () => {
  assertEquals(calculateNutrition(resolved, { quantity: 2, unit: 'piece' }).grams, 240);
  assertEquals(calculateNutrition(resolved, { quantity: 1, unit: 'serving' }).calories, 165);
});
Deno.test('nutrition engine zero grams returns zeros', () => {
  assertEquals(calculateNutrition(resolved, { quantity: 0, unit: 'g' }).protein_g, 0);
});
Deno.test('nutrition engine missing serving and unit mismatch fail typed', async () => {
  await assertRejects(async () => calculateNutrition(resolved, { quantity: 1, unit: 'cup' }), GatewayError);
  await assertRejects(async () => calculateNutrition(resolved, { quantity: 100, unit: 'ml' }), GatewayError);
});
Deno.test('nutrition engine per-serving basis', () => {
  const v = { ...version, nutrition: { calories: 200, protein_g: 10, carbs_g: 20, fat_g: 5, fiber_g: 2, serving_size: 50 } };
  assertEquals(calculateNutrition({ ...resolved, nutritionVersion: v }, { quantity: 100, unit: 'g' }).calories, 400);
});
Deno.test('provenance resolution priority barcode then mapping then normalized name', async () => {
  assertEquals((await resolveFoodCandidate(db() as any, { name: 'wrong', barcode: '0123' })).provenance.matched_by, 'barcode');
  assertEquals((await resolveFoodCandidate(db() as any, { name: 'wrong', source: 'usda', external_id: '171077' })).provenance.matched_by, 'external_mapping');
  assertEquals((await resolveFoodCandidate(db() as any, { name: 'chicken breast' })).provenance.matched_by, 'normalized_name');
});
Deno.test('provenance unresolved does not fake external provider data', async () => {
  const r = await resolveFoodCandidate(db() as any, { name: 'Mystery Food' });
  assertEquals(r.needs_verification, true);
  assertEquals(r.provenance.kind, 'ai_estimate_pending_verification');
});
Deno.test('analyze-food contract includes canonical nutrition only when resolved', async () => {
  const policy = await loadModelPolicy();
  const result = await buildAnalyzeFoodResponse(db() as any, policy, { items: [ { name: 'Chicken Breast', confidence: 0.9, assumptions: [], barcode: '0123', portion: { food_name: 'Chicken Breast', quantity: 150, unit: 'g', grams: 150, confidence: 0.9, assumptions: [] } }, { name: 'Mystery Food', confidence: 0.4, assumptions: [], portion: { food_name: 'Mystery Food', quantity: 1, unit: 'piece', grams: 50, confidence: 0.4, assumptions: [] } } ], overall_confidence: 0.7, requires_confirmation: false, verification_recommended: false });
  assertEquals(result.items[0].nutrition?.calories, 248);
  assertEquals(result.items[0].provenance.kind, 'internal');
  assertEquals(result.items[1].nutrition, undefined);
  assertEquals(result.items[1].needs_verification, true);
});
Deno.test('food pipeline threshold behavior', async () => {
  const policy = await loadModelPolicy();
  assertEquals(thresholdDecision(policy, 0.9), 'auto_accept');
  assertEquals(thresholdDecision(policy, 0.6), 'needs_user_confirm');
  assertEquals(thresholdDecision(policy, 0.2), 'reject');
});
