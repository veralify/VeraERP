// @ts-nocheck
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { normalizeAiRoute } from '../routes.ts';
import { generateRecommendationCandidates } from '../recommendation-candidates.ts';
import { executeTool } from '../tools.ts';

function db(seed: Record<string, unknown[]> = {}) {
  const tables = seed;
  return { tables, from(table: string) { tables[table] ??= []; let rows = [...tables[table]]; const q: any = { select: () => q, insert: (v: unknown) => { rows = Array.isArray(v) ? v : [v]; tables[table].push(...rows); return q; }, update: () => q, eq: (c: string, v: unknown) => { rows = rows.filter((r) => r[c] === v); return q; }, gte: (c: string, v: unknown) => { rows = rows.filter((r) => String(r[c]) >= String(v)); return q; }, in: (c: string, vals: unknown[]) => { rows = rows.filter((r) => vals.includes(r[c])); return q; }, order: (c: string, opts: any) => { rows.sort((a,b) => opts?.ascending === false ? String(b[c]).localeCompare(String(a[c])) : String(a[c]).localeCompare(String(b[c]))); return q; }, limit: (n: number) => Promise.resolve({ data: rows.slice(0,n), error: null }), maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }), single: () => Promise.resolve({ data: rows[0] ?? null, error: null }), then: (resolve: any) => resolve({ data: rows, error: null }) }; return q; } };
}

Deno.test('spec endpoint aliases normalize to implemented gateway routes', () => {
  assertEquals(normalizeAiRoute('http://local/api/v1/ai/food-estimate'), 'analyze-food');
  assertEquals(normalizeAiRoute('http://local/api/v1/ai/food-verify'), 'food-verify');
  assertEquals(normalizeAiRoute('http://local/api/v1/ai/progress-analysis'), 'progress-analysis');
  assertEquals(normalizeAiRoute('http://local/functions/v1/ai-gateway/chat'), 'chat');
});

Deno.test('real read tools use caller scope for groups posts sessions and measurements', async () => {
  const userId = 'u1'; const groupId = 'g1'; const sessionId = 's1';
  const mock = db({
    group_members: [{ user_id: userId, group_id: groupId, status: 'active', role: 'member', joined_at: '2026-08-01' }, { user_id: 'u2', group_id: 'g2', status: 'active' }],
    groups: [{ id: groupId, name: 'Protein Club', slug: 'protein', goal_type: 'nutrition', type: 'public', visibility: 'public', is_active: true }, { id: 'g2', name: 'Other', is_active: true }],
    posts: [{ id: 'p1', group_id: groupId, author_id: 'u2', content: 'hello', status: 'published', created_at: '2026-08-20' }, { id: 'p2', group_id: 'g2', content: 'no', status: 'published', created_at: '2026-08-20' }],
    session_bookings: [{ id: 'b1', client_id: userId, session_id: sessionId, status: 'confirmed', booked_at: '2026-08-20' }],
    coach_sessions: [{ id: sessionId, title: 'Check-in', scheduled_at: '2999-01-01T00:00:00Z', duration_minutes: 30, session_type: 'video', status: 'scheduled', coach_id: 'c1' }],
    body_measurements: [{ user_id: userId, measured_at: '2026-08-01', measurement_type: 'waist', value: 80, unit: 'cm' }, { user_id: 'u2', measured_at: '2026-08-01', measurement_type: 'waist', value: 90, unit: 'cm' }],
  });
  assertEquals((await executeTool('get_user_groups', {}, { userId, requestId: 'r', supabase: mock as any })).length, 1);
  assertEquals((await executeTool('get_recent_posts', {}, { userId, requestId: 'r', supabase: mock as any }))[0].id, 'p1');
  assertEquals((await executeTool('get_upcoming_sessions', {}, { userId, requestId: 'r', supabase: mock as any }))[0].id, sessionId);
  assertEquals((await executeTool('get_measurements', {}, { userId, requestId: 'r', supabase: mock as any }))[0].value, 80);
});

Deno.test('candidate generation builds macro, stale goal, and group candidates from DB', async () => {
  const userId = 'u1';
  const mock = db({
    goals: [{ id: 'goal1', user_id: userId, status: 'active', title: 'Cut', type: 'weight_loss', updated_at: '2026-01-01T00:00:00Z' }],
    goal_targets: [{ goal_id: 'goal1', metric: 'protein_g', target_value: 140, unit: 'g', period: 'daily' }],
    daily_nutrition_summaries: [{ user_id: userId, date: '2026-08-30', protein_g: 90, calories: 2000, carbs_g: 200, fat_g: 50, fiber_g: 20 }],
    weight_entries: [{ user_id: userId, measured_at: '2026-08-01', weight_kg: 80 }, { user_id: userId, measured_at: '2026-08-20', weight_kg: 80.05 }],
    group_members: [],
  });
  const candidates = await generateRecommendationCandidates(mock as any, userId);
  assertEquals(candidates.some((c) => c.title.includes('protein_g')), true);
  assertEquals(candidates.some((c) => c.title.includes('Review stale goal')), true);
  assertEquals(candidates.some((c) => c.recommendation_type === 'group'), true);
});

Deno.test('blocked tool still returns explicit NOT_YET_AVAILABLE', async () => {
  const result = await executeTool('get_live_rooms', {}, { userId: 'u', requestId: 'r', supabase: db() as any });
  assertEquals(result.error.code, 'NOT_YET_AVAILABLE');
});
