import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Live' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Live"
      title="Live rooms"
      body="Real-time audio and video rooms for community accountability."
      emptyTitle="No live rooms now"
      emptyBody="When rooms from your communities or coaches are available, they will appear here."
      ctaHref="/live"
      ctaLabel="Learn about live rooms"
    />
  );
}
