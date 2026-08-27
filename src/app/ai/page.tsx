import { FeaturePage } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'AI food tracking',
  description:
    'Use Veralify AI to scan food, verify nutrition, and turn logs into personal insights.',
};

export default function AIPage() {
  return (
    <FeaturePage
      eyebrow="AI"
      title="AI that understands your fitness journey."
      body="Veralify helps turn meal photos and check-ins into structured logs, daily summaries, and recommendations you can act on."
      blocks={[
        {
          eyebrow: 'Food scan',
          title: 'Photo-assisted logging',
          body: 'Scan a meal, review the identified items, and confirm the nutrition before it becomes part of your history.',
        },
        {
          eyebrow: 'Insights',
          title: 'Context-aware summaries',
          body: 'AI connects nutrition, goals, progress, groups, and routines to explain what changed.',
        },
        {
          eyebrow: 'Recommendations',
          title: 'Next best actions',
          body: 'Get nudges for tracking, recovery, community accountability, or coach support without replacing professional judgment.',
        },
      ]}
    />
  );
}
