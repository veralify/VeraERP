import { Card, ErrorMessage, PageHeader, Pager } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { supabaseAdmin } from '@lib/supabaseAdmin';
import type { Metadata } from 'next';

export const metadata: Metadata = { title: 'Coach portal' };

type SearchParams = Promise<{ page?: string; error?: string; connect?: string }>;
type CoachProfile = { id: string; headline: string | null; verification_status: string };
type StripeAccount = {
  onboarding_status: string;
  charges_enabled: boolean;
  payouts_enabled: boolean;
  stripe_account_id: string;
};
type CoachClient = {
  client_id: string;
  status: string;
  started_at: string;
  ended_at: string | null;
};
type Booking = {
  id: string;
  status: string;
  payment_method: string;
  booked_at: string;
  cancelled_at: string | null;
  coach_sessions: {
    title: string;
    scheduled_at: string;
    duration_minutes: number;
    session_type: string;
    status: string;
    client_id: string | null;
  } | null;
};
const pageSize = 10;
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
  if (error) return 'We could not complete that coach action. Try again.';
  return undefined;
}

export default async function CoachPortalPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const [entitlements, { data: coachProfile }] = await Promise.all([
    getUserEntitlements(user.id).catch(() => []),
    supabase
      .from('coach_profiles')
      .select('id, headline, verification_status')
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
            title="Coach access not active"
            body="Your current entitlements do not include VERALIFY_COACH. Consumer Pro remains available from billing."
            ctaHref="/dashboard/billing"
            ctaLabel="Open billing"
          />
        </Card>
      </main>
    );
  }

  const [{ data: stripeAccount }, { data: clients }, { data: bookings, count: bookingCount }] =
    await Promise.all([
      supabaseAdmin
        .from('coach_stripe_accounts')
        .select('onboarding_status, charges_enabled, payouts_enabled, stripe_account_id')
        .eq('coach_id', user.id)
        .maybeSingle(),
      supabase
        .from('coach_clients')
        .select('client_id, status, started_at, ended_at')
        .eq('coach_id', user.id)
        .order('started_at', { ascending: false })
        .limit(25),
      supabase
        .from('session_bookings')
        .select(
          'id, status, payment_method, booked_at, cancelled_at, coach_sessions!inner(title, scheduled_at, duration_minutes, session_type, status, client_id, coach_id)',
          { count: 'exact' },
        )
        .eq('coach_sessions.coach_id', user.id)
        .order('booked_at', { ascending: false })
        .range(from, to)
        .limit(pageSize + 1),
    ]);

  const account = stripeAccount as StripeAccount | null;
  const clientRows = (clients ?? []) as CoachClient[];
  const bookingRows = ((bookings ?? []) as unknown as Booking[]).slice(0, pageSize);
  const hasNext = (bookings?.length ?? 0) > pageSize || from + pageSize < (bookingCount ?? 0);

  return (
    <main className="px-4 py-8 lg:px-8">
      <PageHeader
        eyebrow="Coach portal"
        title="Coach foundations"
        body="Stripe Connect onboarding, granted clients, and session booking states are shown from the live schema."
      />
      <ErrorMessage message={errorMessage(params.error)} />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <Card>
            <h2 className="text-xl font-bold">Session bookings</h2>
            <p className="mt-2 text-sm text-vera-fg-muted">
              Frozen booking state machine: {stateMachine.join(' → ')}.
            </p>
            {bookingRows.length ? (
              <div className="mt-5 divide-y divide-vera-border">
                {bookingRows.map((booking) => (
                  <article key={booking.id} className="py-4">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div>
                        <h3 className="font-semibold">
                          {booking.coach_sessions?.title ?? 'Untitled session'}
                        </h3>
                        <p className="mt-1 text-sm text-vera-fg-muted">
                          {booking.coach_sessions?.scheduled_at
                            ? new Date(booking.coach_sessions.scheduled_at).toLocaleString()
                            : 'Unscheduled'}{' '}
                          · {booking.coach_sessions?.duration_minutes ?? 0} min ·{' '}
                          {booking.payment_method}
                        </p>
                      </div>
                      <span className="rounded-full bg-vera-primary/15 px-3 py-1 text-xs font-semibold text-vera-primary">
                        {booking.status}
                      </span>
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState
                title="No session bookings yet"
                body="Bookings will appear after clients request or pay for coach sessions."
              />
            )}
            <Pager page={page} hasNext={hasNext} basePath="/dashboard/coach" />
          </Card>

          <Card>
            <h2 className="text-xl font-bold">Clients</h2>
            {clientRows.length ? (
              <div className="mt-4 divide-y divide-vera-border">
                {clientRows.map((client) => (
                  <article key={client.client_id} className="py-4">
                    <p className="font-semibold">Client {client.client_id}</p>
                    <p className="text-sm text-vera-fg-muted">
                      {client.status} · started {client.started_at.slice(0, 10)}
                      {client.ended_at ? ` · ended ${client.ended_at.slice(0, 10)}` : ''}
                    </p>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState
                title="No clients granted yet"
                body="Clients who grant coach access will appear here. No sample clients are shown."
              />
            )}
          </Card>
        </div>

        <div className="space-y-6">
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
                title="No coach profile row"
                body="A coach profile must exist before public discovery and Connect onboarding are available."
              />
            )}
          </Card>
        </div>
      </div>
    </main>
  );
}
