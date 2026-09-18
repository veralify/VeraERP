import { StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { Card, Pager } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Users } from 'lucide-react';

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

/**
 * Isolated as its own async server component so `coaches/page.tsx` can wrap
 * just the data-dependent grid in `<Suspense>` — the entitlement gate above
 * it renders immediately, and this streams in behind a `SkeletonGrid`.
 */
export async function CoachesGrid({ page }: { page: number }) {
  const from = (page - 1) * pageSize;
  const to = from + pageSize;
  const supabase = await createSupabaseServerClient();
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

  if (!coaches.length) {
    return (
      <Card>
        <EmptyState
          icon={<Users className="h-6 w-6" strokeWidth={1.75} />}
          title="No verified coaches yet"
          body="Verified published coach profiles will appear here once approved."
        />
      </Card>
    );
  }

  return (
    <>
      <StaggerGroup className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {coaches.map((coach) => (
          <StaggerItem key={coach.id}>
            <a
              href={`/coaches/${coach.id}`}
              className="block h-full rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] transition-[transform,box-shadow,border-color] duration-200 ease-[var(--vera-ease-standard)] hover:-translate-y-1 hover:border-vera-primary hover:shadow-[var(--vera-shadow-md)] focus-visible:-translate-y-1 focus-visible:border-vera-primary focus-visible:shadow-[var(--vera-shadow-md)]"
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
            </a>
          </StaggerItem>
        ))}
      </StaggerGroup>
      <Pager page={page} hasNext={hasNext} basePath="/coaches" />
    </>
  );
}
