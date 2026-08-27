import { CTASection, Hero, MarketingShell } from '@components/marketing/SitePrimitives';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description:
    'Veralify is a fitness and social platform for tracking, connection, and transformation.',
};

export default function AboutPage() {
  return (
    <MarketingShell>
      <Hero
        eyebrow="About"
        title="Veralify turns fitness tracking into accountability."
        body="We are building a fitness and social platform where AI-powered tracking connects to progress insights, communities, live rooms, messaging, and coaches."
        secondaryHref="/help"
        secondaryLabel="Contact us"
      />
      <CTASection
        title="Track. Connect. Transform."
        body="The product exists to make consistency easier: track honestly, understand your patterns, and connect with people who help you keep going."
      />
    </MarketingShell>
  );
}
