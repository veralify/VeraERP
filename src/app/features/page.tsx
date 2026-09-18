import {
  AlternatingFeatureRow,
  CTASection,
  FeatureGrid,
  GlassPanel,
  Hero,
  MarketingShell,
} from '@components/marketing/SitePrimitives';
import { Camera, Radio, TrendingUp, UserCheck } from 'lucide-react';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Features',
  description:
    'AI food scanning, progress tracking, communities, live rooms, and coach discovery — every feature in Veralify Pro.',
};

export default function FeaturesPage() {
  return (
    <MarketingShell>
      <Hero
        eyebrow="Features"
        title="One fitness platform for the full transformation loop."
        body="Track, understand, connect, stay accountable, and transform with Veralify Pro."
        secondaryHref="/pricing"
        secondaryLabel="View pricing"
      />

      <AlternatingFeatureRow
        feature={{
          icon: <Camera className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'AI food scan',
          title: 'Log meals from a photo, then verify the details.',
          body: 'A provenance-first pipeline: AI proposes what it sees, the nutrition engine calculates estimates, and your history stays consistent over time — never silently rewritten.',
          points: [
            'Photo capture with AI portion estimation',
            'You confirm before anything saves',
            'Deterministic calorie and macro math, every time',
          ],
          visual: (
            <GlassPanel>
              <div className="aspect-[4/3] rounded-vera-xl border border-vera-glass-border bg-[linear-gradient(135deg,color-mix(in_srgb,var(--vera-color-nutrition-calories)_25%,transparent),color-mix(in_srgb,var(--vera-color-nutrition-protein)_18%,transparent))] p-5">
                <div className="h-full rounded-vera-lg border border-vera-glass-border bg-vera-glass p-5">
                  <p className="text-sm text-vera-fg-muted">Meal analysis preview</p>
                  <p className="mt-4 text-4xl font-black tracking-tight">Photo → macros</p>
                  <div className="mt-8 grid grid-cols-2 gap-3 text-sm">
                    <span className="rounded-vera-md bg-vera-surface p-3">Calories</span>
                    <span className="rounded-vera-md bg-vera-surface p-3">Protein</span>
                    <span className="rounded-vera-md bg-vera-surface p-3">Carbs</span>
                    <span className="rounded-vera-md bg-vera-surface p-3">Fat</span>
                  </div>
                </div>
              </div>
            </GlassPanel>
          ),
        }}
      />

      <AlternatingFeatureRow
        reverse
        feature={{
          icon: <TrendingUp className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'Progress',
          title: 'Goals, trends, and photos without fake sample data.',
          body: 'Weight, measurements, and progress photos build a real trend line — insight comes from your own history, not a generic template.',
          points: [
            'Goal setup with daily calorie and macro targets',
            'Weight and measurement trend charts',
            'Private progress photos, visible only to you and a granted coach',
          ],
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-primary">
                <TrendingUp className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">Goal progress</p>
              </div>
              <p className="mt-3 text-2xl font-black tracking-tight">On track</p>
              <div className="mt-5 h-24 rounded-vera-lg border border-vera-glass-border bg-[linear-gradient(180deg,color-mix(in_srgb,var(--vera-color-success)_18%,transparent),transparent)]" />
              <p className="mt-4 text-sm text-vera-fg-muted">
                Trend calculated from your logged weight entries
              </p>
            </GlassPanel>
          ),
        }}
      />

      <AlternatingFeatureRow
        feature={{
          icon: <Radio className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'Live rooms',
          title: 'Show up together, in real time.',
          body: 'Voice and video rooms make accountability timely instead of buried in a feed — join a scheduled session or drop into one already live.',
          points: [
            'Voice-first rooms with request-to-speak',
            'Community and coach-hosted sessions',
            'Clear host moderation and speaking states',
          ],
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-coach-accent">
                <Radio className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">Live now</p>
              </div>
              <p className="mt-3 text-xl font-bold">Evening Mobility Session</p>
              <p className="mt-4 text-sm text-vera-fg-muted">8 people live · tap to join</p>
            </GlassPanel>
          ),
        }}
      />

      <AlternatingFeatureRow
        reverse
        feature={{
          icon: <UserCheck className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'Coach discovery',
          title: 'Human support when tracking alone isn’t enough.',
          body: 'Browse verified coaches, book a session, and pay securely — coaching complements the tracking loop rather than replacing it.',
          points: [
            'Verified coach profiles with specialties and rates',
            'Book and pay for a session in one flow',
            'Optional data sharing, permission by permission',
          ],
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-coach-accent">
                <UserCheck className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">Verified coach</p>
              </div>
              <p className="mt-3 text-xl font-bold">Strength & nutrition coaching</p>
              <div className="mt-4 flex flex-wrap gap-2 text-xs">
                {['Strength', 'Nutrition', 'Habit building'].map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full bg-vera-primary/15 px-3 py-1 font-semibold text-vera-primary"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </GlassPanel>
          ),
        }}
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

      <CTASection
        title="Everything unlocks with Veralify Pro."
        body="Start with a 3-day trial, then keep tracking, connecting, and transforming with one subscription."
      />
    </MarketingShell>
  );
}
