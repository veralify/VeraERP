// @ts-nocheck
import type { SupabaseLike } from './types.ts';
import { getActiveGoal, getGoalTargets, getNutritionHistory, getWeightTrend } from './context.ts';
async function many(q: unknown) { const r = await q; if (r?.error) throw new Error(r.error.message); return r?.data ?? []; }
const avg = (rows: unknown[], key: string) => rows.length ? rows.reduce((s, r: any) => s + Number(r[key] ?? 0), 0) / rows.length : 0;
export type RecommendationCandidate = { recommendation_type: 'habit' | 'group' | 'live_room' | 'coach'; target_id?: string | null; title: string; reason: string; score: number; features: Record<string, unknown> };
export async function generateRecommendationCandidates(supabase: SupabaseLike, userId: string): Promise<RecommendationCandidate[]> {
  const goal = await getActiveGoal(supabase, userId);
  const [targets, nutrition, weightTrend] = await Promise.all([getGoalTargets(supabase, goal?.id), getNutritionHistory(supabase, userId, 7), getWeightTrend(supabase, userId, 30)]);
  const candidates: RecommendationCandidate[] = [];
  for (const t of targets) {
    const metric = String(t.metric ?? ''); const target = Number(t.target_value ?? 0); if (!target) continue;
    const actual = avg(nutrition, metric);
    if (actual && actual < target * 0.9) candidates.push({ recommendation_type: 'habit', title: `Improve ${metric}`, reason: `7-day average ${Math.round(actual)} is below target ${target}.`, score: Math.min(1, (target - actual) / target + 0.5), features: { metric, actual, target, goal_id: goal?.id } });
  }
  if (goal?.updated_at && Date.now() - new Date(goal.updated_at).getTime() > 14 * 86400_000) candidates.push({ recommendation_type: 'habit', title: 'Review stale goal', reason: 'Active goal has not been updated recently.', score: 0.62, features: { goal_id: goal.id, updated_at: goal.updated_at } });
  if (weightTrend.delta_kg !== null && Math.abs(weightTrend.delta_kg) < 0.1 && goal?.type?.includes?.('weight')) candidates.push({ recommendation_type: 'coach', title: 'Discuss plateau with a coach', reason: 'Recent weight trend appears flat against a weight-related goal.', score: 0.7, features: { delta_kg: weightTrend.delta_kg, goal_id: goal.id } });
  const memberships = await many(supabase.from('group_members').select('group_id').eq('user_id', userId).eq('status', 'active').limit(50));
  if (goal?.type && memberships.length === 0) candidates.push({ recommendation_type: 'group', title: `Find a ${goal.type} group`, reason: 'User has an active goal and is not currently in an active group.', score: 0.58, features: { goal_type: goal.type } });
  return candidates.sort((a, b) => b.score - a.score).slice(0, 12);
}
