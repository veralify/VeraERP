// @ts-nocheck
import { estimateCostUsd, getTaskPolicy, type ModelPolicy, type RolePolicy } from './registry.ts';
import { type ChatParams, type ChatResult, isProviderFallbackError, OpenRouterClient } from './openrouter.ts';
import { GatewayError, type AiTaskType, type SupabaseLike, type Usage } from './types.ts';
import { logModelRun } from './logging.ts';

export type RoutedChatParams = Omit<ChatParams, 'model' | 'timeoutMs' | 'maxTokens' | 'providerOrder'> & { task: AiTaskType; userId: string; requestId: string; aiRequestId?: string | null; promptVersion: string; toolSchemaVersion: string; safetyPolicyVersion: string; supabase: SupabaseLike };
export type FallbackChainEntry = { model: string; role: string; success: boolean; error_code?: string; error_message?: string; over_budget?: boolean; latency_ms: number; estimated_cost_usd: number };
export type RoutedChatResult = ChatResult & { requestedModel: string; fallbackUsed: boolean; estimatedCostUsd: number; fallbackChain: FallbackChainEntry[] };
export function resolveModelsForTask(policy: ModelPolicy, task: AiTaskType) { return getTaskPolicy(policy, task); }
function candidates(policy: ModelPolicy, task: AiTaskType): Array<{ model: string; roleName: string; rolePolicy: RolePolicy }> {
  const { taskPolicy, rolePolicy, models } = getTaskPolicy(policy, task);
  const out = models.map((model) => ({ model, roleName: taskPolicy.role, rolePolicy }));
  if (taskPolicy.budget_fallback_role) {
    const cheap = policy.roles[taskPolicy.budget_fallback_role];
    if (cheap) out.push(...[cheap.primary_model, ...cheap.fallback_models].map((model) => ({ model, roleName: taskPolicy.budget_fallback_role!, rolePolicy: cheap })));
  }
  return out;
}
function codeOf(e: unknown) { return e instanceof GatewayError ? e.code : e instanceof Error ? e.name : 'UNKNOWN'; }
export async function routedChat(policy: ModelPolicy, client: OpenRouterClient, params: RoutedChatParams): Promise<RoutedChatResult> {
  const chain: FallbackChainEntry[] = [];
  const all = candidates(policy, params.task);
  const requestedModel = all[0]?.model;
  let last: unknown;
  for (let i = 0; i < all.length; i++) {
    const { model, roleName, rolePolicy } = all[i];
    const start = performance.now();
    let usage: Usage = { inputTokens: 0, outputTokens: 0, reasoningTokens: null };
    let cost = 0;
    try {
      const result = await client.chat({ ...params, model, timeoutMs: rolePolicy.timeout_ms, maxTokens: rolePolicy.max_tokens, providerOrder: rolePolicy.provider_preferences.order });
      usage = result.usage;
      cost = estimateCostUsd(policy, result.model || model, usage.inputTokens, usage.outputTokens);
      const overBudget = cost > rolePolicy.max_cost_per_run_usd;
      const entry = { model: result.model || model, role: roleName, success: !overBudget, over_budget: overBudget, latency_ms: Math.round(performance.now() - start), estimated_cost_usd: cost };
      chain.push(entry);
      await logModelRun(params.supabase, { requestId: params.requestId, aiRequestId: params.aiRequestId, userId: params.userId, task: params.task, model: result.model || model, provider: result.provider, modelPolicyVersion: policy.model_policy_version, promptVersion: params.promptVersion, toolSchemaVersion: params.toolSchemaVersion, safetyPolicyVersion: params.safetyPolicyVersion, latencyMs: entry.latency_ms, estimatedCostUsd: cost, success: !overBudget, structuredOutputValid: true, usage });
      if (overBudget) throw new GatewayError('MODEL_UNAVAILABLE', 'Model run exceeded configured per-run budget.', 502);
      return { ...result, requestedModel, fallbackUsed: chain.length > 1, estimatedCostUsd: cost, fallbackChain: chain };
    } catch (e) {
      last = e;
      if (chain[chain.length - 1]?.model !== model || chain[chain.length - 1]?.success !== false) {
        chain.push({ model, role: roleName, success: false, error_code: codeOf(e), error_message: e instanceof Error ? e.message : String(e), over_budget: e instanceof GatewayError && e.message.includes('budget'), latency_ms: Math.round(performance.now() - start), estimated_cost_usd: cost || estimateCostUsd(policy, model, usage.inputTokens, usage.outputTokens) });
      } else {
        chain[chain.length - 1].error_code = codeOf(e);
        chain[chain.length - 1].error_message = e instanceof Error ? e.message : String(e);
      }
      await logModelRun(params.supabase, { requestId: params.requestId, aiRequestId: params.aiRequestId, userId: params.userId, task: params.task, model, provider: null, modelPolicyVersion: policy.model_policy_version, promptVersion: params.promptVersion, toolSchemaVersion: params.toolSchemaVersion, safetyPolicyVersion: params.safetyPolicyVersion, latencyMs: Math.round(performance.now() - start), estimatedCostUsd: estimateCostUsd(policy, model, usage.inputTokens, usage.outputTokens), success: false, structuredOutputValid: false, usage });
      const canFallback = i < all.length - 1 && (isProviderFallbackError(e) || e instanceof GatewayError);
      if (!canFallback) {
        const err = e instanceof GatewayError ? e : new GatewayError('MODEL_UNAVAILABLE', e instanceof Error ? e.message : 'No model available', 502);
        err.details = { ...(err.details ?? {}), fallback_chain: chain };
        throw err;
      }
    }
  }
  const err = last instanceof GatewayError ? last : new GatewayError('MODEL_UNAVAILABLE', last instanceof Error ? last.message : 'No model available', 502);
  err.details = { ...(err.details ?? {}), fallback_chain: chain };
  throw err;
}
export async function runStructured<T>(policy: ModelPolicy, client: OpenRouterClient, params: RoutedChatParams, parse: (raw: string) => T, repairInstruction = 'Return only valid JSON matching the provided schema.'): Promise<RoutedChatResult & { parsed: T }> {
  try {
    const first = await routedChat(policy, client, params);
    try { return { ...first, parsed: parse(first.content) }; }
    catch (_e) { const repaired = await routedChat(policy, client, { ...params, messages: [...params.messages, { role: 'assistant', content: first.content }, { role: 'user', content: repairInstruction }] }); return { ...repaired, fallbackUsed: first.fallbackUsed || repaired.fallbackUsed, fallbackChain: [...first.fallbackChain, ...repaired.fallbackChain], parsed: parse(repaired.content) }; }
  } catch (e) { if (e instanceof GatewayError) throw e; throw new GatewayError('STRUCTURED_OUTPUT_INVALID', e instanceof Error ? e.message : 'Structured output failed', 502); }
}
