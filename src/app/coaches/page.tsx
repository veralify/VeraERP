import { FeaturePage } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Coaches',
  description: 'Discover fitness coaches and build accountable coach-client relationships.',
};

export default function CoachesPage() {
  return (
    <FeaturePage
      eyebrow="Coaches"
      title="Human coaching when members need more support."
      body="Coach discovery connects members to experts while future coach tools support clients, sessions, groups, messages, and scheduling."
      blocks={[
        {
          eyebrow: 'Discovery',
          title: 'Find the right fit',
          body: 'Members can discover coaches aligned with their goals, needs, and preferred accountability style.',
        },
        {
          eyebrow: 'Relationships',
          title: 'Coach-client context',
          body: 'Coaching builds on member-approved access to progress, nutrition, and goals.',
        },
        {
          eyebrow: 'Marketplace',
          title: 'Prepared for services',
          body: 'Future 1:1 real-time coaching payments use Stripe Connect while digital Pro remains subscription-gated.',
        },
      ]}
    />
  );
}
