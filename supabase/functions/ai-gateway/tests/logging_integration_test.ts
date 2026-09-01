// @ts-nocheck
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { createAiRequest, logModelRun, logToolCall, completeAiRequest } from '../logging.ts';

Deno.test('guarded local DB logging integration writes and reads back', async () => {
  const net = await Deno.permissions.query({ name: 'net' as any });
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key || net.state !== 'granted') {
    console.warn('skipping local DB logging integration: SUPABASE_URL/SERVICE_ROLE or --allow-net unavailable');
    return;
  }
  const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
  const profileRes = await fetch(`${url}/rest/v1/profiles?select=id&limit=1`, { headers });
  const profiles = await profileRes.json();
  if (!profiles?.[0]?.id) { console.warn('skipping local DB logging integration: no profiles row'); return; }
  const userId = profiles[0].id;
  const requestId = `itest-${crypto.randomUUID()}`;
  const supabase = { from(table: string) { const state: any = { table, filters: [], body: null, select: '*' }; const q: any = { select: (sel = '*') => { state.select = sel; return q; }, insert: (body: unknown) => { state.method = 'POST'; state.body = body; return q; }, update: (body: unknown) => { state.method = 'PATCH'; state.body = body; return q; }, eq: (col: string, val: unknown) => { state.filters.push(`${col}=eq.${encodeURIComponent(String(val))}`); return q; }, single: async () => run(true), maybeSingle: async () => run(true), then: (resolve: any, reject: any) => run(false).then(resolve, reject) }; async function run(single: boolean) { const qs = [`select=${state.select}`, ...state.filters].join('&'); const res = await fetch(`${url}/rest/v1/${table}?${qs}`, { method: state.method ?? 'GET', headers: { ...headers, Prefer: 'return=representation' }, body: state.body ? JSON.stringify(state.body) : undefined }); const data = await res.json().catch(() => null); return { data: single ? data?.[0] : data, error: res.ok ? null : data }; } return q; } };
  const aiRequestId = await createAiRequest(supabase as any, { userId, task: 'itest', requestId, modelRequested: 'policy:test' });
  await logModelRun(supabase as any, { requestId, aiRequestId, userId, task: 'simple_chat', model: 'itest-model', provider: 'itest', modelPolicyVersion: 'itest', promptVersion: 'itest', toolSchemaVersion: 'itest', safetyPolicyVersion: 'itest', latencyMs: 1, estimatedCostUsd: 0, success: true, structuredOutputValid: true, usage: { inputTokens: 1, outputTokens: 1 } });
  await logToolCall(supabase as any, { aiRequestId, toolName: 'get_user_profile', arguments: {}, result: { ok: true }, success: true });
  await completeAiRequest(supabase as any, aiRequestId, 'succeeded', 'itest-model', false);
  const read = await fetch(`${url}/rest/v1/ai_requests?request_id=eq.${requestId}&select=id,status`, { headers });
  const rows = await read.json();
  assertEquals(rows[0].status, 'succeeded');
});
