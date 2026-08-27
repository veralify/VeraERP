import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'AI' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="AI"
      title="AI insights"
      body="Food analysis, daily summaries, and recommendations will be generated from your confirmed data."
      emptyTitle="No AI insights yet"
      emptyBody="Track meals, goals, or progress first so AI can summarize real context."
      ctaHref="/dashboard/track"
      ctaLabel="Start tracking"
    />
  );
}
