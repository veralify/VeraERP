import { Banner } from '@components/generic/Banner';
import { Reveal } from '@components/generic/Motion';
import { SkeletonList } from '@components/generic/Skeleton';
import { CoachProfileForm } from '@components/member/CoachProfileForm';
import { CoachSessionForm } from '@components/member/CoachSessionForm';
import { Card, ErrorMessage, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import { FileWarning, Lock } from 'lucide-react';
import type { Metadata } from 'next';
import { Suspense } from 'react';
import { BookingsList } from './BookingsList';
import { ClientsList } from './ClientsList';
import { SessionSlotsList } from './SessionSlotsList';

export const metadata: Metadata = { title: 'Coach portal' };

type SearchParams = Promise<{ page?: string; error?: string; connect?: string; saved?: string }>;
type CoachProfile = {
  id: string;
  headline: string | null;
  bio: string | null;
  specialties: string[];
  years_experience: number | null;
  hourly_rate: number | null;
  currency: string;
  location: string | null;
  online_only: boolean;
  verification_status: string;
};
type StripeAccount = {
  onboarding_status: string;
  charges_enabled: boolean;
  payouts_enabled: boolean;
  stripe_account_id: string;
};
const stateMachine = [
  'pending',
  'payment_required',
  'paid',
  'confirmed',
  'completed',
  'cancelled',
  'refunded',
];

function errorMessage(error?: string) {
  if (error === 'coach-entitlement')
    return 'VERALIFY_COACH entitlement is required to access coach tools.';
  if (error === 'coach-profile')
    return 'A coach profile is required before Stripe Connect onboarding can start.';
  if (error === 'invalid-profile') return 'Enter a headline and a valid 3-letter currency code.';
  if (error === 'save-profile') return 'Could not save your coach profile. Try again.';
  if (error === 'invalid-session')
    return 'Enter a title, format, duration, and a future date/time.';
  if (error === 'save-session') return 'Could not publish that session. Try again.';
  if (error) return 'We could not complete that coach action. Try again.';
  return undefined;
}

function savedMessage(saved?: string) {
  if (saved === 'profile') return 'Coach profile saved.';
  if (saved === 'session') return 'Session slot published.';
  return undefined;
}

export default async function CoachPortalPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const [entitlements, { data: coachProfile }] = await Promise.all([
    getUserEntitlements(user.id).catch(() => []),
    supabase
      .from('coach_profiles')
      .select(
        'id, headline, bio, specialties, years_experience, hourly_rate, currency, location, online_only, verification_status',
      )
      .eq('id', user.id)
      .maybeSingle(),
  ]);
  const profile = coachProfile as CoachProfile | null;
  const canUseCoachPortal = hasEntitlement(entitlements, 'VERALIFY_COACH') || Boolean(profile);

  if (!canUseCoachPortal) {
    return (
      <main className="px-4 py-8 lg:px-8">
        <PageHeader
          eyebrow="Coach portal"
          title="Coach tools require VERALIFY_COACH."
          body="Upgrade when coach tools are available for your account. No coach dashboard data is shown without a coach entitlement or coach profile."
        />
        <Card>
          <EmptyState
            icon={<Lock className="h-6 w-6" strokeWidth={1.75} />}
            title="Coach access not active"
            body="Your current entitlements do not include VERALIFY_COACH. Consumer Pro remains available from billing."
            ctaHref="/dashboard/billing"
            ctaLabel="Open billing"
          />
        </Card>
      </main>
    );
  }

  const { data: stripeAccount } = await supabaseAdmin
    .from('coach_stripe_accounts')
    .select('onboarding_status, charges_enabled, payouts_enabled, stripe_account_id')
    .eq('coach_id', user.id)
    .maybeSingle();
  const account = stripeAccount as StripeAccount | null;

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Coach portal"
        title="Coach foundations"
        body="Stripe Connect onboarding, granted clients, and session booking states are shown from the live schema."
      />
      <ErrorMessage message={errorMessage(params.error)} />
      <Banner variant="success" message={savedMessage(params.saved)} className="mt-3" />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Reveal variants={fadeUp}>
            <Card>
              <h2 className="text-xl font-bold">Session bookings</h2>
              <p className="mt-2 text-sm text-vera-fg-muted">
                Frozen booking state machine: {stateMachine.join(' → ')}.
              </p>
              <Suspense fallback={<SkeletonList count={4} className="mt-5" />}>
                <BookingsList coachId={user.id} page={page} />
              </Suspense>
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.05}>
            <Card>
              <h2 className="text-xl font-bold">Your session slots</h2>
              <Suspense fallback={<SkeletonList count={3} className="mt-4" />}>
                <SessionSlotsList coachId={user.id} />
              </Suspense>
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.1}>
            <CoachSessionForm />
          </Reveal>

          <Reveal variants={fadeUp} delay={0.1}>
            <CoachProfileForm existing={profile} />
          </Reveal>

          <Reveal variants={fadeUp} delay={0.15}>
            <Card>
              <h2 className="text-xl font-bold">Clients</h2>
              <Suspense fallback={<SkeletonList count={2} className="mt-4" />}>
                <ClientsList coachId={user.id} />
              </Suspense>
            </Card>
          </Reveal>
        </div>

        <div className="space-y-6">
          <Reveal variants={fadeUp} delay={0.05}>
            <Card>
              <h2 className="text-xl font-bold">Stripe Connect</h2>
              <dl className="mt-4 space-y-3 text-sm">
                <div>
                  <dt className="text-vera-fg-muted">Onboarding</dt>
                  <dd className="font-semibold">{account?.onboarding_status ?? 'not_started'}</dd>
                </div>
                <div>
                  <dt className="text-vera-fg-muted">Charges</dt>
                  <dd className="font-semibold">
                    {account?.charges_enabled ? 'Enabled' : 'Not enabled'}
                  </dd>
                </div>
                <div>
                  <dt className="text-vera-fg-muted">Payouts</dt>
                  <dd className="font-semibold">
                    {account?.payouts_enabled ? 'Enabled' : 'Not enabled'}
                  </dd>
                </div>
              </dl>
              <form action="/api/stripe/connect/onboarding" method="POST" className="mt-6">
                <button type="submit" className="btn-apple w-full">
                  {account ? 'Continue Connect onboarding' : 'Start Connect onboarding'}
                </button>
              </form>
            </Card>
          </Reveal>

          <Reveal variants={fadeUp} delay={0.1}>
            <Card>
              <h2 className="text-xl font-bold">Coach profile</h2>
              {profile ? (
                <div className="mt-3 text-sm text-vera-fg-muted">
                  <p className="font-semibold text-vera-fg">
                    {profile.headline ?? 'No headline yet'}
                  </p>
                  <p className="mt-2">Verification: {profile.verification_status}</p>
                </div>
              ) : (
                <EmptyState
                  icon={<FileWarning className="h-6 w-6" strokeWidth={1.75} />}
                  title="No coach profile row"
                  body="A coach profile must exist before public discovery and Connect onboarding are available."
                />
              )}
            </Card>
          </Reveal>
        </div>
      </div>
    </main>
  );
}
