import { SkeletonGrid } from '@components/generic/Skeleton';
import { Card, PageHeader } from '@components/member/DashboardPrimitives';
import { EmptyState } from '@components/member/EmptyState';
import { getUserEntitlements, hasEntitlement } from '@lib/api/entitlements';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { Lock } from 'lucide-react';
import type { Metadata } from 'next';
import { Suspense } from 'react';
import { CoachesGrid } from './CoachesGrid';

export const metadata: Metadata = {
  title: 'Coach discovery',
  description:
    'Discover verified Veralify coaches when coach discovery is included in your entitlement set.',
};

type SearchParams = Promise<{ page?: string }>;

export default async function CoachesPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);
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
              icon={<Lock className="h-6 w-6" strokeWidth={1.75} />}
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

  return (
    <main className="bg-vera-bg px-6 py-20 text-vera-fg">
      <div className="mx-auto max-w-6xl">
        <PageHeader
          eyebrow="Coach discovery"
          title="Verified coaches"
          body="Browse published coach profiles. Booking and payments are handled separately through the coach marketplace rails."
        />
        <Suspense key={page} fallback={<SkeletonGrid />}>
          <CoachesGrid page={page} />
        </Suspense>
      </div>
    </main>
  );
}
