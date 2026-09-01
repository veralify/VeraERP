// @ts-nocheck
import { type ModelRunMeta, type SupabaseLike } from './types.ts';

export async function createAiRequest(supabase: SupabaseLike, input: { userId: string; task: string; requestId: string; modelRequested: string }) {
  const res = await supabase.from('ai_requests').insert({ user_id: input.userId, task: input.task, request_id: input.requestId, status: 'running', model_requested: input.modelRequested, fallback_used: false }).select('id').single();
  if (res?.error) throw new Error(`ai_requests insert failed: ${res.error.message}`);
  return res?.data?.id ?? null;
}
export async function completeAiRequest(supabase: SupabaseLike, aiRequestId: string | null | undefined, status: 'succeeded' | 'failed', modelUsed?: string, fallbackUsed?: boolean) {
  if (!aiRequestId) return;
  const res = await supabase.from('ai_requests').update({ status, model_used: modelUsed, fallback_used: !!fallbackUsed, completed_at: new Date().toISOString() }).eq('id', aiRequestId);
  if (res?.error) throw new Error(`ai_requests update failed: ${res.error.message}`);
}
export async function logModelRun(supabase: SupabaseLike, meta: ModelRunMeta) {
  if (!meta.aiRequestId) { console.warn('ai_model_runs skipped: ai_request_id unavailable for non-persisted harness call', { request_id: meta.requestId, task: meta.task, model: meta.model }); return; }
  const res = await supabase.from('ai_model_runs').insert({ ai_request_id: meta.aiRequestId, model: meta.model, provider: meta.provider ?? 'unknown', model_policy_version: meta.modelPolicyVersion, prompt_version: meta.promptVersion, tool_schema_version: meta.toolSchemaVersion, safety_policy_version: meta.safetyPolicyVersion, input_tokens: meta.usage.inputTokens, output_tokens: meta.usage.outputTokens, reasoning_tokens: meta.usage.reasoningTokens ?? null, latency_ms: meta.latencyMs, estimated_cost: meta.estimatedCostUsd, success: meta.success, structured_output_valid: meta.structuredOutputValid });
  if (res?.error) throw new Error(`ai_model_runs insert failed: ${res.error.message}`);
}
export async function logToolCall(supabase: SupabaseLike, row: { aiRequestId?: string | null; toolName: string; arguments: unknown; result: unknown; success: boolean }) {
  if (!row.aiRequestId) { console.warn('ai_tool_calls skipped: ai_request_id unavailable for non-persisted harness call', { tool_name: row.toolName }); return; }
  const res = await supabase.from('ai_tool_calls').insert({ ai_request_id: row.aiRequestId, tool_name: row.toolName, arguments: row.arguments ?? {}, result: row.result ?? null, success: row.success });
  if (res?.error) throw new Error(`ai_tool_calls insert failed: ${res.error.message}`);
}
export async function auditSafetyBlock(supabase: SupabaseLike, userId: string, requestId: string, classification: unknown) {
  const res = await supabase.from('audit_logs').insert({ actor_id: userId, target_type: 'ai_request', target_id: requestId, action: 'ai_safety_block', metadata: { request_id: requestId, classification } });
  if (res?.error) console.warn('audit_logs ai_safety_block failed', res.error.message);
}
