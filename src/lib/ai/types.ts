export type FoodCandidate = {
  name: string;
  canonical_hint?: string;
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
export type FoodAnalysisResult = {
  items: Array<FoodCandidate & { portion: PortionEstimate }>;
  overall_confidence: number;
  requires_confirmation: boolean;
  verification_recommended: boolean;
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
