import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Profile' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Profile"
      title="Profile"
      body="Your member identity, preferences, and future privacy controls."
      emptyTitle="Profile details not completed"
      emptyBody="Additional profile editing arrives in a later phase. Your authenticated account is active."
    />
  );
}
