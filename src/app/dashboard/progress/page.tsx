import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Progress' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Progress"
      title="Progress dashboard"
      body="Review measurements, progress photos, trends, and milestones once you create them."
      emptyTitle="No progress updates yet"
      emptyBody="Add a check-in or progress photo to begin seeing trends over time."
      ctaHref="/dashboard/track"
      ctaLabel="Create check-in"
    />
  );
}
