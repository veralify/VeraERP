export type FoodCandidate = {
  name: string;
  canonical_hint?: string;
  barcode?: string | null;
  external_id?: string | null;
  source?: string | null;
  confidence: number;
  assumptions: string[];
};
export type PortionEstimate = {
  food_name: string;
  quantity: number;
  unit: string;
  grams: number;
  confidence: number;
  assumptions: string[];
};
export type FoodNutrition = {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g?: number;
  sodium_mg?: number;
};
export type AnalyzeFoodItem = {
  food_id?: string;
  food_nutrition_version_id?: string;
  name: string;
  portion: PortionEstimate;
  confidence: number;
  assumptions: string[];
  nutrition?: FoodNutrition;
  provenance: {
    kind: 'internal' | 'external' | 'ai_estimate_pending_verification';
    source?: string | null;
    external_id?: string | null;
    matched_by?: string;
    nutrition_version_id?: string | null;
  };
  needs_verification: boolean;
};
export type FoodAnalysisResult = {
  items: AnalyzeFoodItem[];
  overall_confidence: number;
  requires_confirmation: boolean;
  verification_recommended: boolean;
  threshold_decision?: 'auto_accept' | 'needs_user_confirm' | 'reject';
};
export type CoachResponse = {
  message: string;
  safety_disclaimer?: string;
  suggested_actions: string[];
  tool_results_used: string[];
  confidence: number;
};
export type InsightResponse = {
  type: 'nutrition' | 'progress' | 'goal' | 'general';
  title: string;
  body: string;
  supporting_facts: string[];
  confidence: number;
  valid_until?: string | null;
};
export type RecommendationResponse = {
  recommendations: Array<{
    recommendation_type: 'group' | 'live_room' | 'habit' | 'coach';
    target_id?: string | null;
    title: string;
    reason: string;
    score: number;
  }>;
  confidence: number;
};
export type GatewayEnvelope<T> = {
  request_id: string;
  result: T;
  model_policy_version?: string;
  safety_policy_version?: string;
};
