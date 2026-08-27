// @ts-nocheck
import { GatewayError, type SupabaseLike } from './types.ts';
import type { CanonicalFood, FoodNutritionVersion, FoodServing, ResolvedFoodForNutrition } from './nutrition-engine.ts';

export type FoodCandidateInput = { name: string; barcode?: string | null; external_id?: string | null; source?: string | null; confidence?: number };
export type ProvenanceKind = 'internal' | 'external' | 'ai_estimate_pending_verification';
export type ProvenanceMeta = { kind: ProvenanceKind; source?: string | null; external_id?: string | null; matched_by?: 'barcode' | 'external_mapping' | 'normalized_name' | 'provider' | 'none'; nutrition_version_id?: string | null; food_source_priority?: number | null };
export type ResolvedFoodCandidate = { candidate: FoodCandidateInput; resolved?: ResolvedFoodForNutrition; provenance: ProvenanceMeta; needs_verification: boolean };
export type ExternalFoodProviderResult = { food: CanonicalFood; nutritionVersion: FoodNutritionVersion; servings: FoodServing[]; provenance: ProvenanceMeta };
export interface ExternalFoodProvider { fetchFood(candidate: FoodCandidateInput): Promise<ExternalFoodProviderResult | null>; }
export class ConfiguredExternalFoodProvider implements ExternalFoodProvider {
  constructor(private apiKey = Deno.env.get('FOOD_DATA_PROVIDER_KEY')) {}
  async fetchFood(): Promise<ExternalFoodProviderResult | null> {
    if (!this.apiKey) throw new GatewayError('NOT_YET_AVAILABLE', 'FOOD_DATA_PROVIDER_KEY is not configured; external food provider lookup is disabled.', 503, { code: 'NOT_CONFIGURED' });
    throw new GatewayError('NOT_YET_AVAILABLE', 'External food provider integration boundary is defined but provider adapter is not implemented yet.', 501);
  }
}
const normalize = (s: string) => s.trim().toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, ' ').trim().replace(/\s+/g, ' ');
async function one(q: unknown) { const r = await q; if (r?.error) throw new Error(r.error.message); return r?.data ?? null; }
async function many(q: unknown) { const r = await q; if (r?.error) throw new Error(r.error.message); return r?.data ?? []; }
async function buildResolved(supabase: SupabaseLike, food: CanonicalFood, meta: ProvenanceMeta): Promise<ResolvedFoodCandidate> {
  const versions = await many(supabase.from('food_nutrition_versions').select('*').eq('food_id', food.id).order('version', { ascending: false }).limit(1));
  const version = versions[0];
  if (!version) throw new GatewayError('NOT_YET_AVAILABLE', `No nutrition version for food ${food.id}`, 502);
  const servings = await many(supabase.from('food_servings').select('*').eq('food_id', food.id));
  return { candidate: { name: food.name, barcode: food.barcode, external_id: food.external_id, source: food.source }, resolved: { food, nutritionVersion: version, servings }, provenance: { ...meta, nutrition_version_id: version.id }, needs_verification: false };
}
export async function resolveFoodCandidate(supabase: SupabaseLike, candidate: FoodCandidateInput, provider: ExternalFoodProvider = new ConfiguredExternalFoodProvider()): Promise<ResolvedFoodCandidate> {
  if (candidate.barcode) {
    const food = await one(supabase.from('foods').select('*').eq('barcode', candidate.barcode).maybeSingle());
    if (food) return await buildResolved(supabase, food, { kind: 'internal', source: food.source, external_id: food.external_id, matched_by: 'barcode' });
  }
  if (candidate.external_id && candidate.source) {
    const source = await one(supabase.from('food_sources').select('*').eq('code', candidate.source).eq('is_active', true).maybeSingle());
    if (source) {
      const mapping = await one(supabase.from('food_external_mappings').select('*').eq('food_source_id', source.id).eq('external_id', candidate.external_id).maybeSingle());
      if (mapping) {
        const food = await one(supabase.from('foods').select('*').eq('id', mapping.food_id).maybeSingle());
        if (food) return await buildResolved(supabase, food, { kind: 'internal', source: source.code, external_id: candidate.external_id, matched_by: 'external_mapping', food_source_priority: source.priority });
      }
    }
  }
  const foods = await many(supabase.from('foods').select('*').limit(250));
  const wanted = normalize(candidate.name);
  const exact = foods.find((f: CanonicalFood) => normalize(f.name) === wanted);
  if (exact) return await buildResolved(supabase, exact, { kind: 'internal', source: exact.source, external_id: exact.external_id, matched_by: 'normalized_name' });
  try {
    const external = await provider.fetchFood(candidate);
    if (external) return { candidate, resolved: { food: external.food, nutritionVersion: external.nutritionVersion, servings: external.servings }, provenance: external.provenance, needs_verification: false };
  } catch (e) {
    if (!(e instanceof GatewayError && e.code === 'NOT_YET_AVAILABLE')) throw e;
  }
  return { candidate, provenance: { kind: 'ai_estimate_pending_verification', matched_by: 'none' }, needs_verification: true };
}
export async function resolveFoodCandidates(supabase: SupabaseLike, candidates: FoodCandidateInput[], provider?: ExternalFoodProvider) { return await Promise.all(candidates.map((c) => resolveFoodCandidate(supabase, c, provider))); }
