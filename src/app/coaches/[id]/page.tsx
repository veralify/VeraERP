import { Reveal } from '@components/generic/Motion';
import { SkeletonList } from '@components/generic/Skeleton';
import { Card, ErrorMessage, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { fadeUp } from '@lib/motion/variants';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Lock } from 'lucide-react';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Suspense } from 'react';
import { SessionsList } from './SessionsList';

type Params = Promise<{ id: string }>;
type SearchParams = Promise<{ error?: string }>;

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
  rating: number;
  review_count: number;
  public_profiles: { display_name: string | null; username: string | null } | null;
};

function errorMessage(error?: string) {
  if (error === 'session-unavailable') return 'That session was just booked by someone else.';
  if (error === 'own-session') return 'You cannot book your own session.';
  if (error === 'coach-not-payable')
    return 'This coach has not finished payment setup yet — booking is unavailable.';
  if (error === 'booking-failed') return 'Could not create that booking. Try again.';
  if (error) return 'We could not complete that booking. Try again.';
  return undefined;
}

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { id } = await params;
  return { title: `Coach ${id}` };
}

export default async function CoachDetailPage({
  params,
  searchParams,
}: {
  params: Params;
  searchParams: SearchParams;
}) {
  const { id } = await params;
  const search = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const entitlements = user ? await getUserEntitlements(user.id).catch(() => []) : [];
  const canDiscover =
    hasEntitlement(entitlements, 'coach_discovery') || hasEntitlement(entitlements, 'VERALIFY_PRO');

  if (!canDiscover) {
    return (
      <main className="bg-vera-bg px-6 py-20 text-vera-fg">
        <div className="mx-auto max-w-3xl">
          <PageHeader
            eyebrow="Coach discovery"
            title="Coach discovery is included with Pro."
            body="Sign in and start Veralify Pro to view coach profiles and book sessions."
          />
          <Card>
            <EmptyState
              icon={<Lock className="h-6 w-6" strokeWidth={1.75} />}
              title="Coach discovery locked"
              body="Sign in and start Veralify Pro to browse verified coaches."
              ctaHref={user ? '/dashboard/billing' : '/pricing'}
              ctaLabel={user ? 'Open billing' : 'View pricing'}
            />
          </Card>
        </div>
      </main>
    );
  }

  const { data: coach } = await supabase
    .from('coach_profiles')
    .select(
      'id, headline, bio, specialties, years_experience, hourly_rate, currency, location, online_only, rating, review_count, public_profiles(display_name, username)',
    )
    .eq('id', id)
    .eq('verification_status', 'verified')
    .maybeSingle();
  if (!coach) notFound();
  const profile = coach as unknown as CoachProfile;

  return (
    <main className="bg-vera-bg px-6 py-20 text-vera-fg">
      <div className="mx-auto max-w-4xl">
        <PageHeader
          eyebrow="Coach discovery"
          title={profile.headline ?? 'Coach profile'}
          body={
            profile.public_profiles?.display_name ?? profile.public_profiles?.username ?? undefined
          }
        />
        <ErrorMessage message={errorMessage(search.error)} />
        <Reveal variants={fadeUp}>
          <Card className="mb-6">
            <p className="text-sm leading-6 text-vera-fg-muted">{profile.bio ?? 'No bio yet.'}</p>
            <dl className="mt-5 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
              <div>
                <dt className="text-vera-fg-muted">Experience</dt>
                <dd className="font-semibold">{profile.years_experience ?? '—'} years</dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Rate</dt>
                <dd className="font-semibold">
                  {profile.hourly_rate
                    ? `${profile.currency.toUpperCase()} ${profile.hourly_rate}/hr`
                    : '—'}
                </dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Rating</dt>
                <dd className="font-semibold">
                  {profile.rating} ({profile.review_count})
                </dd>
              </div>
              <div>
                <dt className="text-vera-fg-muted">Format</dt>
                <dd className="font-semibold">
                  {profile.online_only ? 'Online' : (profile.location ?? 'Flexible')}
                </dd>
              </div>
            </dl>
          </Card>
        </Reveal>

        <Reveal variants={fadeUp} delay={0.08}>
          <Card>
            <h2 className="text-xl font-bold">Available sessions</h2>
            <Suspense fallback={<SkeletonList count={3} className="mt-4" />}>
              <SessionsList
                coachId={id}
                hourlyRate={profile.hourly_rate}
                currency={profile.currency}
                isSignedIn={Boolean(user)}
              />
            </Suspense>
          </Card>
        </Reveal>
      </div>
    </main>
  );
}
