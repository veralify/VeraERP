import { FeatureGrid, Hero, MarketingShell } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Features',
  description: 'Explore Veralify AI, tracking, communities, live rooms, and coaches.',
};

export default function FeaturesPage() {
  return (
    <MarketingShell>
      <Hero
        eyebrow="Features"
        title="One fitness platform for the full transformation loop."
        body="Track, understand, connect, stay accountable, and transform with Veralify Pro."
      />
      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl">
          <FeatureGrid
            blocks={[
              {
                eyebrow: 'AI',
                title: 'Food and insight AI',
                body: 'Scan food, confirm logs, and turn history into summaries and recommendations.',
              },
              {
                eyebrow: 'Tracking',
                title: 'Nutrition and progress',
                body: 'Measure meals, goals, photos, and trends without fake sample data.',
              },
              {
                eyebrow: 'Social',
                title: 'Groups, live rooms, coaches',
                body: 'Connect with communities and human support for accountability.',
              },
            ]}
          />
        </div>
      </section>
    </MarketingShell>
  );
}
