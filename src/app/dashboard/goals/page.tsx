import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Goals' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Goals"
      title="Goals"
      body="Set and revisit goals that guide your tracking and accountability loop."
      emptyTitle="No goals set yet"
      emptyBody="Create a goal before Veralify can summarize progress against it."
      ctaHref="/dashboard/track"
      ctaLabel="Start with a check-in"
    />
  );
}
