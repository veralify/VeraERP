import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { supabaseAdmin } from '@lib/supabaseAdmin';

/**
 * Whether a user may create/manage a coach profile and start Stripe Connect
 * onboarding. Per docs/EXECUTION_PLAN.md M0.2, this is an OR of three routes
 * so the paid VERALIFY_COACH entitlement stays valid without being the only
 * door in during the founding-coach invite phase:
 *   - an existing coach_profiles row (never lock out a coach who already has one)
 *   - an invite in coach_invites matching their email (unclaimed, or claimed by themself)
 *   - the paid VERALIFY_COACH entitlement
 */
export async function canActAsCoach(userId: string, email: string | null): Promise<boolean> {
  const { data: existingProfile } = await supabaseAdmin
    .from('coach_profiles')
    .select('id')
    .eq('id', userId)
    .maybeSingle();
  if (existingProfile) return true;

  if (email) {
    const { data: invite } = await supabaseAdmin
      .from('coach_invites')
      .select('claimed_by')
      .eq('email', email)
      .maybeSingle();
    if (invite && (invite.claimed_by === null || invite.claimed_by === userId)) return true;
  }

  const entitlements = await getUserEntitlements(userId).catch(() => []);
  return hasEntitlement(entitlements, 'VERALIFY_COACH');
}

/**
 * Stamps an unclaimed invite matching `email` as claimed by `userId`. Safe to
 * call unconditionally when a coach profile is created — a no-op if there is
 * no matching invite, or it's already claimed by this same user.
 */
export async function claimCoachInvite(userId: string, email: string | null): Promise<void> {
  if (!email) return;
  await supabaseAdmin
    .from('coach_invites')
    .update({ claimed_by: userId, claimed_at: new Date().toISOString() })
    .eq('email', email)
    .is('claimed_by', null);
}
