// @ts-nocheck
import { GatewayError, type SupabaseLike } from './types.ts';
import type { ModelPolicy } from './registry.ts';

type Bucket = { count: number; resetAt: number };
const buckets = new Map<string, Bucket>();

export async function enforceRateLimit(userId: string, policy: ModelPolicy) {
  const limit = Number(Deno.env.get('AI_GATEWAY_PER_USER_PER_MINUTE') ?? policy.limits.per_user_per_minute);
  const now = Date.now();
  const bucket = buckets.get(userId) ?? { count: 0, resetAt: now + 60_000 };
  if (bucket.resetAt < now) {
    bucket.count = 0;
    bucket.resetAt = now + 60_000;
  }
  bucket.count += 1;
  buckets.set(userId, bucket);
  if (bucket.count > limit) {
    throw new GatewayError('RATE_LIMITED', 'AI rate limit exceeded. Please retry shortly.', 429);
  }
}

export async function enforceDailyCostCeiling(
  supabase: SupabaseLike,
  userId: string,
  policy: ModelPolicy,
  projectedCostUsd = 0,
) {
  const ceiling = Number(Deno.env.get('AI_GATEWAY_DAILY_COST_CEILING_USD') ?? policy.limits.daily_cost_ceiling_usd);
  let spent = 0;
  try {
    const since = new Date();
    since.setUTCHours(0, 0, 0, 0);
    const reqRes = await supabase
      .from('ai_requests')
      .select('id')
      .eq('user_id', userId)
      .gte('created_at', since.toISOString())
      .limit(1000);
    if (reqRes?.error) throw new Error(reqRes.error.message);
    const ids = (reqRes?.data ?? []).map((r: { id: string }) => r.id).filter(Boolean);
    if (ids.length > 0) {
      const runsRes = await supabase
        .from('ai_model_runs')
        .select('estimated_cost')
        .in('ai_request_id', ids)
        .eq('success', true)
        .limit(1000);
      if (runsRes?.error) throw new Error(runsRes.error.message);
      spent = (runsRes?.data ?? []).reduce(
        (sum: number, r: { estimated_cost?: number | string }) => sum + Number(r.estimated_cost ?? 0),
        0,
      );
    }
  } catch (e) {
    console.warn('TODO-BLOCKED daily AI cost lookup failed; applying projected-cost-only ceiling', {
      user_id: userId,
      error: e instanceof Error ? e.message : String(e),
    });
  }

  if (spent + projectedCostUsd > ceiling) {
    throw new GatewayError('COST_CEILING_EXCEEDED', 'Daily AI cost ceiling reached for this account.', 429, {
      spent,
      projectedCostUsd,
      ceiling,
    });
  }
}

export function resetInMemoryRateLimitsForTests() {
  buckets.clear();
}
