import { FeaturePage } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Live rooms',
  description: 'Live audio and video rooms for fitness accountability and community.',
};

export default function LivePage() {
  return (
    <FeaturePage
      eyebrow="Live"
      title="Real-time rooms for real accountability."
      body="Live audio and video rooms help members show up, ask questions, and stay connected when motivation drops."
      blocks={[
        {
          eyebrow: 'Discovery',
          title: 'Find rooms that fit',
          body: 'Discover active rooms from communities, coaches, and accountability groups.',
        },
        {
          eyebrow: 'Participation',
          title: 'Join with clear roles',
          body: 'Room participation is server-authorized and designed for safe community interaction.',
        },
        {
          eyebrow: 'Premium access',
          title: 'Included in Pro',
          body: 'Live rooms and premium live rooms are part of the single Pro entitlement set.',
        },
      ]}
    />
  );
}
