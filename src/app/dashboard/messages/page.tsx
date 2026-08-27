import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Messages' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Messages"
      title="Messages"
      body="Direct and group conversations connected to accountability."
      emptyTitle="No messages yet"
      emptyBody="Conversations with groups, members, or coaches will appear here after they exist."
    />
  );
}
