import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Track' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Track"
      title="Start tracking"
      body="Capture food, check-ins, and progress moments as real entries."
      emptyTitle="No tracking entries yet"
      emptyBody="Take your first action when you are ready. Veralify will not show sample entries or invented progress."
      ctaHref="/dashboard/nutrition"
      ctaLabel="Open nutrition"
    />
  );
}
