// @ts-nocheck
import type { SupabaseLike } from './types.ts';
export async function getOrCreateConversation(supabase: SupabaseLike, userId: string, conversationId?: string | null, type = 'coach') {
  if (conversationId) {
    const existing = await supabase.from('ai_conversations').select('*').eq('id', conversationId).eq('user_id', userId).maybeSingle();
    if (existing?.error) throw new Error(existing.error.message);
    if (existing?.data) return existing.data;
  }
  const res = await supabase.from('ai_conversations').insert({ user_id: userId, type, title: type === 'coach' ? 'AI Coach' : type }).select('*').single();
  if (res?.error) throw new Error(res.error.message);
  return res.data;
}
export async function saveAiMessage(supabase: SupabaseLike, input: { conversationId: string; role: 'user'|'assistant'|'system'|'tool'; content: unknown; model?: string | null }) {
  const res = await supabase.from('ai_messages').insert({ conversation_id: input.conversationId, role: input.role, content: input.content, model: input.model ?? null }).select('id').single();
  if (res?.error) throw new Error(res.error.message);
  return res.data;
}
export async function getRecentAiMessages(supabase: SupabaseLike, conversationId: string, limit = 12) {
  const res = await supabase.from('ai_messages').select('role,content,model,created_at').eq('conversation_id', conversationId).order('created_at', { ascending: false }).limit(limit);
  if (res?.error) throw new Error(res.error.message);
  return (res.data ?? []).reverse();
}
export async function persistFoodEstimate(supabase: SupabaseLike, input: { userId: string; imagePath?: string | null; model: string; result: unknown; confidence?: number | null; verified?: boolean }) {
  const res = await supabase.from('ai_food_estimates').insert({ user_id: input.userId, image_path: input.imagePath ?? null, model: input.model, result: input.result, confidence: input.confidence ?? null, verified: !!input.verified, corrected_by_user: false }).select('id').single();
  if (res?.error) throw new Error(res.error.message);
  return res.data;
}
const today = () => new Date().toISOString().slice(0, 10);
export async function upsertDailyInsight(supabase: SupabaseLike, input: { userId: string; type: string; title: string; body: string; sourceData: unknown; model: string; validUntil?: string | null }) {
  const day = today();
  const existing = await supabase.from('ai_insights').select('*').eq('user_id', input.userId).eq('type', input.type).gte('created_at', `${day}T00:00:00.000Z`).limit(1);
  if (existing?.error) throw new Error(existing.error.message);
  if (existing?.data?.[0]) return { row: existing.data[0], created: false };
  const res = await supabase.from('ai_insights').insert({ user_id: input.userId, type: input.type, title: input.title, body: input.body, source_data: input.sourceData, model: input.model, valid_until: input.validUntil ?? null }).select('*').single();
  if (res?.error) throw new Error(res.error.message);
  return { row: res.data, created: true };
}
export async function persistRecommendations(supabase: SupabaseLike, userId: string, model: string, recs: Array<{ recommendation_type: string; target_id?: string | null; title: string; reason: string; score: number }>) {
  if (!recs.length) return [];
  const res = await supabase.from('ai_recommendations').insert(recs.map((r) => ({ user_id: userId, model, recommendation_type: r.recommendation_type, target_id: r.target_id ?? null, title: r.title, reason: r.reason, score: r.score }))).select('*');
  if (res?.error) throw new Error(res.error.message);
  return res.data ?? [];
}
export async function persistFeedback(supabase: SupabaseLike, input: { userId: string; aiRequestId: string; rating?: number | null; feedback?: string | null }) {
  const res = await supabase.from('ai_feedback').insert({ user_id: input.userId, ai_request_id: input.aiRequestId, rating: input.rating ?? null, feedback: input.feedback ?? null }).select('*').single();
  if (res?.error) throw new Error(res.error.message);
  return res.data;
}
