// @ts-nocheck
import type { ModelPolicy } from './registry.ts';
import { calculateNutrition, type PortionInput } from './nutrition-engine.ts';
import { resolveFoodCandidates, type ExternalFoodProvider, type FoodCandidateInput, type ResolvedFoodCandidate } from './provenance.ts';
import type { FoodAnalysisResult } from './schemas.ts';
import type { SupabaseLike } from './types.ts';

export type AnalyzeFoodContractItem = {
  food_id?: string;
  food_nutrition_version_id?: string;
  name: string;
  portion: PortionInput & { grams?: number | null };
  confidence: number;
  assumptions: string[];
  nutrition?: {
    calories: number;
    protein_g: number;
    carbs_g: number;
    fat_g: number;
    fiber_g: number;
    sugar_g?: number;
    sodium_mg?: number;
  };
  provenance: ResolvedFoodCandidate['provenance'];
  needs_verification: boolean;
};
export type AnalyzeFoodContract = {
  items: AnalyzeFoodContractItem[];
  overall_confidence: number;
  requires_confirmation: boolean;
  verification_recommended: boolean;
  threshold_decision: 'auto_accept' | 'needs_user_confirm' | 'reject';
};

export function thresholdDecision(policy: ModelPolicy, confidence: number) {
  const p = policy.food_pipeline ?? { auto_accept_threshold: 0.82, needs_user_confirm_threshold: 0.6, reject_threshold: 0.35 };
  if (confidence >= p.auto_accept_threshold) return 'auto_accept';
  if (confidence >= p.reject_threshold) return 'needs_user_confirm';
  return 'reject';
}
export async function buildAnalyzeFoodResponse(supabase: SupabaseLike, policy: ModelPolicy, vision: FoodAnalysisResult, provider?: ExternalFoodProvider): Promise<AnalyzeFoodContract> {
  const candidates: FoodCandidateInput[] = vision.items.map((item) => ({ name: item.name, barcode: item.barcode ?? null, external_id: item.external_id ?? null, source: item.source ?? null, confidence: item.confidence }));
  const resolved = await resolveFoodCandidates(supabase, candidates, provider);
  const items = vision.items.map((item, index) => {
    const r = resolved[index];
    const portion = item.portion;
    if (!r.resolved) return { name: item.name, portion, confidence: item.confidence, assumptions: item.assumptions, provenance: r.provenance, needs_verification: true };
    const n = calculateNutrition(r.resolved, portion);
    return {
      food_id: r.resolved.food.id,
      food_nutrition_version_id: r.resolved.nutritionVersion.id,
      name: r.resolved.food.name,
      portion: { ...portion, grams: n.grams },
      confidence: item.confidence,
      assumptions: item.assumptions,
      nutrition: { calories: n.calories, protein_g: n.protein_g, carbs_g: n.carbs_g, fat_g: n.fat_g, fiber_g: n.fiber_g, sugar_g: n.sugar_g, sodium_mg: n.sodium_mg },
      provenance: r.provenance,
      needs_verification: false,
    };
  });
  const decision = thresholdDecision(policy, vision.overall_confidence);
  return { items, overall_confidence: vision.overall_confidence, requires_confirmation: vision.requires_confirmation || decision !== 'auto_accept' || items.some((i) => i.needs_verification), verification_recommended: vision.verification_recommended || decision !== 'auto_accept', threshold_decision: decision };
}
