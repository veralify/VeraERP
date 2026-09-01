import { Card, PageHeader, Pager } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { createSupabaseServerClient } from '@lib/supabase/server';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Coach discovery',
  description:
    'Discover verified Veralify coaches when coach discovery is included in your entitlement set.',
};

type SearchParams = Promise<{ page?: string }>;
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
const pageSize = 12;

export default async function CoachesPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
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
        <div className="mx-auto max-w-5xl">
          <PageHeader
            eyebrow="Coach discovery"
            title="Coach discovery is included with Pro."
            body="The frozen entitlement set lists coach_discovery as a Pro feature, so verified coach listings are gated until your account has an active entitlement."
          />
          <Card>
            <EmptyState
              title="Coach discovery locked"
              body="Sign in and start Veralify Pro to browse verified coaches. No public coach data is exposed without the entitlement."
              ctaHref={user ? '/dashboard/billing' : '/pricing'}
              ctaLabel={user ? 'Open billing' : 'View pricing'}
            />
          </Card>
        </div>
      </main>
    );
  }

  const { data, count } = await supabase
    .from('coach_profiles')
    .select(
      'id, headline, bio, specialties, years_experience, hourly_rate, currency, location, online_only, rating, review_count, public_profiles(display_name, username)',
      { count: 'exact' },
    )
    .eq('verification_status', 'verified')
    .order('rating', { ascending: false })
    .range(from, to)
    .limit(pageSize + 1);
  const coaches = ((data ?? []) as unknown as CoachProfile[]).slice(0, pageSize);
  const hasNext = (data?.length ?? 0) > pageSize || from + pageSize < (count ?? 0);

  return (
    <main className="bg-vera-bg px-6 py-20 text-vera-fg">
      <div className="mx-auto max-w-6xl">
        <PageHeader
          eyebrow="Coach discovery"
          title="Verified coaches"
          body="Browse published coach profiles. Booking and payments are handled separately through the coach marketplace rails."
        />
        {coaches.length ? (
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
            {coaches.map((coach) => (
              <article
                key={coach.id}
                className="rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)]"
              >
                <p className="text-sm font-semibold text-vera-primary">
                  {coach.public_profiles?.display_name ??
                    coach.public_profiles?.username ??
                    'Verified coach'}
                </p>
                <h2 className="mt-2 text-xl font-bold">{coach.headline ?? 'Coach profile'}</h2>
                <p className="mt-3 line-clamp-4 text-sm leading-6 text-vera-fg-muted">
                  {coach.bio ?? 'No bio yet.'}
                </p>
                <div className="mt-4 flex flex-wrap gap-2">
                  {coach.specialties.slice(0, 4).map((specialty) => (
                    <span
                      key={specialty}
                      className="rounded-full bg-vera-primary/15 px-3 py-1 text-xs font-semibold text-vera-primary"
                    >
                      {specialty}
                    </span>
                  ))}
                </div>
                <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <dt className="text-vera-fg-muted">Experience</dt>
                    <dd className="font-semibold">{coach.years_experience ?? '—'} years</dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Rate</dt>
                    <dd className="font-semibold">
                      {coach.hourly_rate
                        ? `${coach.currency.toUpperCase()} ${coach.hourly_rate}/hr`
                        : '—'}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Rating</dt>
                    <dd className="font-semibold">
                      {coach.rating} ({coach.review_count})
                    </dd>
                  </div>
                  <div>
                    <dt className="text-vera-fg-muted">Format</dt>
                    <dd className="font-semibold">
                      {coach.online_only ? 'Online' : (coach.location ?? 'Flexible')}
                    </dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        ) : (
          <Card>
            <EmptyState
              title="No verified coaches yet"
              body="Verified published coach profiles will appear here once approved."
            />
          </Card>
        )}
        <Pager page={page} hasNext={hasNext} basePath="/coaches" />
      </div>
    </main>
  );
}
