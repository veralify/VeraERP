import { FeaturePage } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Communities',
  description: 'Fitness groups for accountability, progress sharing, and support.',
};

export default function CommunitiesPage() {
  return (
    <FeaturePage
      eyebrow="Communities"
      title="Find people moving toward similar goals."
      body="Veralify communities make progress social through groups, shared check-ins, messaging, and accountability."
      blocks={[
        {
          eyebrow: 'Groups',
          title: 'Goal-aligned spaces',
          body: 'Join groups around nutrition consistency, strength, endurance, weight change, or habits.',
        },
        {
          eyebrow: 'Sharing',
          title: 'Progress with context',
          body: 'Share milestones and updates with communities that understand the effort behind them.',
        },
        {
          eyebrow: 'Messaging',
          title: 'Keep accountability close',
          body: 'Direct and group messaging supports follow-up after logs, live rooms, and coach sessions.',
        },
      ]}
    />
  );
}
