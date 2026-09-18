import { SkeletonGrid } from '@components/generic/Skeleton';
import { PageHeader } from '@components/member/DashboardPrimitives';
import type { Metadata } from 'next';
import { Suspense } from 'react';
import { CoachesGrid } from './CoachesGrid';

export const metadata: Metadata = {
  title: 'Coach discovery',
  description: 'Browse verified Veralify coaches and book a session.',
};

type SearchParams = Promise<{ page?: string }>;

export default async function CoachesPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page) || 1);

  return (
    <main className="relative isolate overflow-hidden bg-vera-bg px-6 py-20 text-vera-fg">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_right,color-mix(in_srgb,var(--vera-color-coach-accent)_16%,transparent),transparent_36rem)]" />
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
