import { MemberPage } from '@components/member/MemberPage';
import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Nutrition' };
export default function Page() {
  return (
    <MemberPage
      eyebrow="Nutrition"
      title="Nutrition log"
      body="Meals, water, macros, and AI-assisted food analysis will live here."
      emptyTitle="No meals logged yet"
      emptyBody="Log a meal to begin building your nutrition history. Until then, this area stays empty."
      ctaHref="/dashboard/track"
      ctaLabel="Add first meal"
    />
  );
}
