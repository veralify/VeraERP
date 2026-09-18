import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import {
  CTASection,
  Hero,
  MarketingShell,
  SectionHeader,
} from '@components/marketing/SitePrimitives';
import { fadeUp } from '@lib/motion/variants';
import { Camera, Flame, Users } from 'lucide-react';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description:
    'Veralify is a fitness and social platform for tracking, connection, and transformation.',
};

const pillars = [
  {
    icon: Camera,
    title: 'Track',
    body: 'Precise nutrition, progress, goals, and trends — logged honestly, without fake sample data standing in for your own history.',
  },
  {
    icon: Users,
    title: 'Connect',
    body: 'Groups, posts, messaging, live rooms, and coach discovery — accountability comes from people, not just numbers on a screen.',
  },
  {
    icon: Flame,
    title: 'Transform',
    body: 'AI guidance, streaks, and coaching turn daily logging into a plan you actually follow through on.',
  },
];

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

      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl">
          <SectionHeader
            eyebrow="Why we built this"
            title="Consistency fails when tracking is a chore and support is nowhere."
            body="Most fitness apps ask you to log data into a void. Veralify closes the loop: what you track feeds insight, insight feeds connection, and connection is what actually keeps people going."
          />
          <StaggerGroup className="mt-12 grid gap-5 md:grid-cols-3">
            {pillars.map((pillar) => (
              <StaggerItem
                key={pillar.title}
                as="article"
                className="rounded-vera-xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] transition-[transform,box-shadow,border-color] duration-200 ease-[var(--vera-ease-standard)] hover:-translate-y-1 hover:border-vera-primary/40 hover:shadow-[var(--vera-shadow-md)]"
              >
                <pillar.icon className="h-6 w-6 text-vera-primary" strokeWidth={1.75} />
                <h3 className="mt-4 text-xl font-bold tracking-tight">{pillar.title}</h3>
                <p className="mt-3 text-sm leading-6 text-vera-fg-muted">{pillar.body}</p>
              </StaggerItem>
            ))}
          </StaggerGroup>
        </div>
      </section>

      <section className="px-6 py-20">
        <Reveal
          className="mx-auto max-w-4xl rounded-vera-2xl border border-vera-border bg-vera-bg-subtle p-8 sm:p-12"
          variants={fadeUp}
        >
          <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
            How we operate
          </p>
          <p className="mt-4 text-lg leading-8 text-vera-fg-muted">
            Veralify is built in the open with a small, focused team. We ship deterministic
            nutrition math instead of guesswork, keep AI provenance visible rather than hidden, and
            treat every data domain — nutrition, progress photos, mood — as opt-in and permissioned,
            including what a coach can see. We're early: features ship as they're genuinely ready,
            not on a marketing calendar.
          </p>
        </Reveal>
      </section>

      <CTASection
        title="Track. Connect. Transform."
        body="The product exists to make consistency easier: track honestly, understand your patterns, and connect with people who help you keep going."
      />
    </MarketingShell>
  );
}
