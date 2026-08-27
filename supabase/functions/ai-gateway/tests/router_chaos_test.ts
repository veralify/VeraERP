// @ts-nocheck
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { loadModelPolicy } from '../registry.ts';
import { OpenRouterClient } from '../openrouter.ts';
import { routedChat } from '../router.ts';
import { GatewayError } from '../types.ts';

const supabase = { from() { const q: any = { select: () => q, insert: () => Promise.resolve({ data: [], error: null }), update: () => q, eq: () => q, gte: () => q, in: () => q, order: () => q, limit: () => Promise.resolve({ data: [], error: null }), maybeSingle: () => Promise.resolve({ data: null, error: null }), single: () => Promise.resolve({ data: null, error: null }), then: (resolve: any) => resolve({ data: [], error: null }) }; return q; } };
const params = (task = 'simple_chat') => ({ task, userId: 'u', requestId: crypto.randomUUID(), promptVersion: 'test@1', toolSchemaVersion: 'test@1', safetyPolicyVersion: 'test@1', supabase: supabase as any, messages: [{ role: 'user' as const, content: 'hello' }] });
const ok = (model: string, usage = { prompt_tokens: 100, completion_tokens: 20 }) => new Response(JSON.stringify({ model, choices: [{ message: { content: '{"message":"ok","suggested_actions":[],"tool_results_used":[],"confidence":0.8}' } }], usage }), { status: 200 });

Deno.test('chaos: primary outage falls back and records chain telemetry', async () => {
  const policy = await loadModelPolicy(); let calls = 0;
  const client = new OpenRouterClient('test', async (_i, init) => { calls++; const body = JSON.parse(String(init?.body)); if (calls <= 3) return new Response('outage', { status: 500 }); return ok(body.model); });
  const res = await routedChat(policy, client, params('simple_chat'));
  assertEquals(res.fallbackUsed, true);
  assertEquals(res.fallbackChain[0].success, false);
  assertEquals(res.fallbackChain.at(-1)?.success, true);
});

Deno.test('chaos: all providers fail with typed error and chain telemetry', async () => {
  const policy = await loadModelPolicy();
  const client = new OpenRouterClient('test', async () => new Response('down', { status: 500 }));
  const err = await assertRejects(() => routedChat(policy, client, params('cheap_multimodal')), GatewayError);
  assertEquals(err.code, 'MODEL_UNAVAILABLE');
  assertEquals(Array.isArray(err.details?.fallback_chain), true);
});

Deno.test('chaos: over-budget escalates to configured cheaper role', async () => {
  const policy = await loadModelPolicy();
  policy.roles.elite_reasoning.max_cost_per_run_usd = 0.000001;
  policy.roles.elite_reasoning_fallback.max_cost_per_run_usd = 0.000001;
  policy.roles.fast_general.max_cost_per_run_usd = 1;
  let calls = 0;
  const client = new OpenRouterClient('test', async (_i, init) => { calls++; const body = JSON.parse(String(init?.body)); const cheap = body.model === policy.roles.fast_general.primary_model; return ok(body.model, cheap ? { prompt_tokens: 10, completion_tokens: 5 } : { prompt_tokens: 1000000, completion_tokens: 1000000 }); });
  const res = await routedChat(policy, client, params('advanced_chat'));
  assertEquals(res.fallbackChain.some((e) => e.over_budget), true);
  assertEquals(res.fallbackChain.at(-1)?.role, 'fast_general');
  assertEquals(res.fallbackChain.at(-1)?.success, true);
  assertEquals(calls >= 3, true);
});
