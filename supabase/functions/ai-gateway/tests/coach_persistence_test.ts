// @ts-nocheck
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { buildCoachContext, trimContextToBudget } from '../context.ts';
import { executeTool } from '../tools.ts';
import { classifySafety, enforceInputSafety } from '../safety.ts';
import { upsertDailyInsight } from '../persistence.ts';
import { GatewayError } from '../types.ts';

function mockDb(seed: Record<string, unknown[]> = {}) {
  const tables = seed;
  return {
    tables,
    from(table: string) {
      tables[table] ??= [];
      let rows = [...tables[table]];
      const q: any = {
        select: () => q,
        insert: (value: unknown) => { const arr = Array.isArray(value) ? value : [value]; const inserted = arr.map((v) => ({ id: crypto.randomUUID(), created_at: new Date().toISOString(), updated_at: new Date().toISOString(), ...v })); tables[table].push(...inserted); rows = inserted; return q; },
        update: (value: unknown) => { rows.forEach((r) => Object.assign(r, value)); return Promise.resolve({ data: rows, error: null }); },
        eq: (col: string, val: unknown) => { rows = rows.filter((r) => r[col] === val); return q; },
        gte: (col: string, val: unknown) => { rows = rows.filter((r) => String(r[col]) >= String(val)); return q; },
        order: (col: string, opts: any) => { rows.sort((a,b) => opts?.ascending === false ? String(b[col]).localeCompare(String(a[col])) : String(a[col]).localeCompare(String(b[col]))); return q; },
        limit: (n: number) => Promise.resolve({ data: rows.slice(0,n), error: null }),
        maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
        single: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
        then: (resolve: any) => resolve({ data: rows, error: null }),
      };
      return q;
    },
  };
}

Deno.test('context assembly trims to token budget and stays caller-scoped', async () => {
  const userId = 'user-a';
  const db = mockDb({
    profiles: [{ id: userId, display_name: 'A' }, { id: 'user-b', display_name: 'B' }],
    goals: [{ id: 'goal-a', user_id: userId, status: 'active', title: 'Protein', type: 'nutrition' }, { id: 'goal-b', user_id: 'user-b', status: 'active', title: 'Other' }],
    goal_targets: [{ goal_id: 'goal-a', metric: 'protein_g', target_value: 120 }],
    daily_nutrition_summaries: Array.from({ length: 30 }, (_, i) => ({ user_id: userId, date: `2026-08-${String(i + 1).padStart(2, '0')}`, calories: 2000 + i, protein_g: 100, carbs_g: 200, fat_g: 60, fiber_g: 20, water_ml: 1000, meal_count: 3 })),
    weight_entries: [{ user_id: userId, measured_at: '2026-08-01', weight_kg: 80 }, { user_id: userId, measured_at: '2026-08-20', weight_kg: 79 }],
    food_logs: Array.from({ length: 30 }, (_, i) => ({ user_id: userId, id: `log-${i}`, logged_at: `2026-08-${String(i + 1).padStart(2, '0')}T00:00:00Z`, notes: 'x'.repeat(100) })),
  });
  const context = await buildCoachContext(db as any, userId, 30, 1200);
  assertEquals(context.profile.id, userId);
  assertEquals(context.goal.id, 'goal-a');
  assertEquals(JSON.stringify(context).length <= 1200, true);
});

Deno.test('tool loop authorization rejects cross-user ids', async () => {
  const db = mockDb();
  await assertRejects(() => executeTool('get_weight_trend', { user_id: 'other-user' }, { userId: 'caller', requestId: 'r', supabase: db as any }), GatewayError, 'another user');
});

Deno.test('health safety refusal path returns typed refusal', async () => {
  const c = classifySafety('How do I lose 10 kg in 1 week with 400 calories?');
  assertEquals(c.allowed, false);
  const err = await assertRejects(() => enforceInputSafety('How do I lose 10 kg in 1 week with 400 calories?'), GatewayError);
  assertEquals(err.code, 'SAFETY_REFUSAL');
});

Deno.test('insight idempotency reuses same daily insight', async () => {
  const db = mockDb({ ai_insights: [] });
  const input = { userId: 'u', type: 'nutrition', title: 'T', body: 'B', sourceData: { day: 'today' }, model: 'model' };
  const first = await upsertDailyInsight(db as any, input);
  const second = await upsertDailyInsight(db as any, { ...input, title: 'Different' });
  assertEquals(first.created, true);
  assertEquals(second.created, false);
  assertEquals(db.tables.ai_insights.length, 1);
});
