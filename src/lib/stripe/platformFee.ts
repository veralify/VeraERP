import { supabaseAdmin } from '@lib/supabaseAdmin';

const DEFAULT_PLATFORM_FEE_PERCENTAGE = 15;

/** Latest effective platform fee percentage for a coach, falling back to the default 15%. */
export async function getPlatformFeePercentage(coachId: string): Promise<number> {
  const { data } = await supabaseAdmin
    .from('coach_platform_fees')
    .select('percentage')
    .eq('coach_id', coachId)
    .lte('effective_from', new Date().toISOString())
    .order('effective_from', { ascending: false })
    .limit(1)
    .maybeSingle();
  return data?.percentage ?? DEFAULT_PLATFORM_FEE_PERCENTAGE;
}
