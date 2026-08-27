import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Groups' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Groups"
      title="Groups"
      body="Communities for shared fitness, nutrition, and accountability goals."
      emptyTitle="No groups joined yet"
      emptyBody="Groups you join or create will appear here. Discovery arrives in a later phase."
      ctaHref="/communities"
      ctaLabel="Learn about communities"
    />
  );
}
