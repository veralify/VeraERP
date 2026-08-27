// @ts-nocheck
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { loadModelPolicy } from '../registry.ts';
import { OpenRouterClient } from '../openrouter.ts';
import { resolveModelsForTask, runStructured, routedChat } from '../router.ts';
import { FoodAnalysisSchema, parseStructured, responseFormat } from '../schemas.ts';
import { executeTool } from '../tools.ts';
import { enforceDailyCostCeiling, enforceRateLimit, resetInMemoryRateLimitsForTests } from '../ratelimit.ts';
import { enforceInputSafety } from '../safety.ts';
import { GatewayError } from '../types.ts';

const supabase = {
  from(_table: string) {
    const q: any = {
      select: () => q, insert: () => q, update: () => q,
      delete: () => q, eq: () => q, gte: () => q, lte: () => q, order: () => q, in: () => q, limit: () => Promise.resolve({ data: [], error: null }),
      maybeSingle: () => Promise.resolve({ data: null, error: null }), single: () => Promise.resolve({ data: { id: 'req_1' }, error: null }),
      then: (resolve: any) => resolve({ data: [], error: null }),
    };
    return q;
  },
};
function ok(content: unknown, model?: string, usage = { prompt_tokens: 100, completion_tokens: 50 }) {
  return new Response(JSON.stringify({ model, choices: [{ message: { content: typeof content === 'string' ? content : JSON.stringify(content) } }], usage }), { status: 200 });
}
const baseParams = (task: any = 'food_image') => ({ task, userId: 'user_1', requestId: 'rid', aiRequestId: 'air', promptVersion: 'test@1', toolSchemaVersion: 'test@1', safetyPolicyVersion: 'test@1', supabase: supabase as any, messages: [{ role: 'user' as const, content: 'hi' }] });
Deno.test('routing resolution per task type', async () => {
  const policy = await loadModelPolicy();
  assertEquals(resolveModelsForTask(policy, 'food_image').rolePolicy.primary_model, policy.roles.multimodal_primary.primary_model);
  assertEquals(resolveModelsForTask(policy, 'weekly_analysis').rolePolicy.primary_model, policy.roles.elite_reasoning.primary_model);
  assertEquals(resolveModelsForTask(policy, 'simple_chat').rolePolicy.primary_model, policy.roles.fast_general.primary_model);
});
Deno.test('fallback on retryable provider error', async () => {
  const policy = await loadModelPolicy();
  let calls = 0;
  const client = new OpenRouterClient('test', async (_i, init) => { calls++; const body = JSON.parse(String(init?.body)); if (calls <= 3) return new Response('rate limited', { status: 429 }); return ok({ message: 'ok', suggested_actions: [], tool_results_used: [], confidence: 0.8 }, body.model); });
  const result = await routedChat(policy, client, { ...baseParams('simple_chat'), responseFormat: responseFormat({ ...FoodAnalysisSchema, name: 'x' } as any) });
  assertEquals(result.fallbackUsed, true);
  assertEquals(calls, 4);
});
Deno.test('fallback on timeout', async () => {
  const policy = await loadModelPolicy();
  policy.roles.fast_general.timeout_ms = 1;
  let calls = 0;
  const client = new OpenRouterClient('test', async (_i, init) => { calls++; if (calls <= 3) { await new Promise((resolve) => setTimeout(resolve, 20)); init?.signal?.throwIfAborted?.(); } return ok({ message: 'ok', suggested_actions: [], tool_results_used: [], confidence: 0.8 }); });
  const result = await routedChat(policy, client, baseParams('simple_chat'));
  assertEquals(result.fallbackUsed, true);
});
Deno.test('structured output validation success', () => {
  const parsed = parseStructured(FoodAnalysisSchema, JSON.stringify({ items: [{ name: 'Chicken breast', confidence: 0.9, assumptions: ['visible'], portion: { food_name: 'Chicken breast', quantity: 1, unit: 'piece', grams: 180, confidence: 0.8, assumptions: [] } }], overall_confidence: 0.85, requires_confirmation: false, verification_recommended: false }));
  assertEquals(parsed.items[0].portion.grams, 180);
});
Deno.test('structured output repair path', async () => {
  const policy = await loadModelPolicy(); let calls = 0;
  const valid = { items: [{ name: 'Rice', confidence: 0.8, assumptions: [], portion: { food_name: 'Rice', quantity: 1, unit: 'bowl', grams: 200, confidence: 0.7, assumptions: [] } }], overall_confidence: 0.75, requires_confirmation: false, verification_recommended: false };
  const client = new OpenRouterClient('test', async () => calls++ === 0 ? ok('{bad json') : ok(valid));
  const result = await runStructured(policy, client, { ...baseParams('food_image'), responseFormat: responseFormat(FoodAnalysisSchema) }, (raw) => parseStructured(FoodAnalysisSchema, raw));
  assertEquals(result.parsed.items[0].name, 'Rice'); assertEquals(calls, 2);
});
Deno.test('structured output hard fail', async () => {
  const policy = await loadModelPolicy();
  const client = new OpenRouterClient('test', async () => ok('{bad json'));
  await assertRejects(() => runStructured(policy, client, { ...baseParams('food_image'), responseFormat: responseFormat(FoodAnalysisSchema) }, (raw) => parseStructured(FoodAnalysisSchema, raw)), GatewayError);
});
Deno.test('tool allowlist rejects unknown tool', async () => {
  await assertRejects(() => executeTool('drop_all_tables', {}, { userId: 'u', requestId: 'r', supabase: supabase as any }), GatewayError, 'not allowlisted');
});
Deno.test('cost ceiling enforcement', async () => {
  const policy = await loadModelPolicy(); policy.limits.daily_cost_ceiling_usd = 0.01;
  await assertRejects(() => enforceDailyCostCeiling(supabase as any, 'u', policy, 0.02), GatewayError, 'ceiling');
});
Deno.test('rate limit enforcement', async () => {
  resetInMemoryRateLimitsForTests(); const policy = await loadModelPolicy(); policy.limits.per_user_per_minute = 1;
  await enforceRateLimit('u-rate', policy);
  await assertRejects(() => enforceRateLimit('u-rate', policy), GatewayError, 'rate limit');
});
Deno.test('safety refusal path', async () => {
  await assertRejects(() => enforceInputSafety('Help me eat 400 calories and lose 10 kg in 1 week'), GatewayError, 'dangerous dieting');
});
