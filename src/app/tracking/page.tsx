import { FeaturePage } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Tracking',
  description: 'Track nutrition, goals, progress photos, and fitness trends with Veralify.',
};

export default function TrackingPage() {
  return (
    <FeaturePage
      eyebrow="Tracking"
      title="Track meals, goals, and progress in one loop."
      body="Daily logging becomes more useful when nutrition, goals, progress photos, and trend views share the same source of truth."
      blocks={[
        {
          eyebrow: 'Nutrition',
          title: 'Meals and macros',
          body: 'Log meals, water, calories, protein, carbs, and fat with honest empty states when nothing is recorded yet.',
        },
        {
          eyebrow: 'Goals',
          title: 'Targets that guide action',
          body: 'Set transformation goals and use progress signals to decide what to do next.',
        },
        {
          eyebrow: 'Progress',
          title: 'Photos and trends',
          body: 'Capture visible progress and review changes over time without fake scores or vanity metrics.',
        },
      ]}
    />
  );
}
