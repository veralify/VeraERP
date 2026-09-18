import { billingOptions } from '@config/billing';
import {
  Brain,
  Camera,
  ChevronRight,
  Flame,
  Radio,
  Target,
  TrendingUp,
  UserCheck,
  Users,
} from 'lucide-react';
import { HeroVisual } from './HeroVisual';
import {
  AlternatingFeatureRow,
  CTASection,
  FAQ,
  FeatureGrid,
  GlassPanel,
  Hero,
  HowItWorks,
  MarketingShell,
  SectionHeader,
} from './SitePrimitives';

const onboardingSteps = [
  {
    title: 'Set your goal',
    body: 'Lose, maintain, or gain — tell us the direction and your starting point.',
  },
  {
    title: 'Get your plan',
    body: 'Daily calorie and macro targets calculated from your profile, not a generic template.',
  },
  {
    title: 'Scan your first meal',
    body: 'Photo in, AI proposes the food, you confirm the details before it saves.',
  },
  {
    title: 'Start your trial',
    body: '3 days of full Pro access — tracking, communities, live rooms, and coach discovery.',
  },
];

const avatarTones = [
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_35%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_25%,var(--vera-color-secondary)_20%)]',
  'bg-[color-mix(in_srgb,var(--vera-color-secondary)_35%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-coach-accent)_30%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_20%,var(--vera-color-coach-accent)_20%)]',
  'bg-[color-mix(in_srgb,var(--vera-color-secondary)_25%,var(--vera-color-coach-accent)_15%)]',
];

const loop = [
  { label: 'Track', icon: Camera },
  { label: 'AI understands', icon: Brain },
  { label: 'Personal insight', icon: TrendingUp },
  { label: 'Connect', icon: Users },
  { label: 'Community or coach', icon: UserCheck },
  { label: 'Accountability', icon: Target },
  { label: 'Transform', icon: Flame },
];

export function HomePage() {
  return (
    <MarketingShell>
      <Hero
        eyebrow="Veralify fitness"
        title="Track. Connect. Transform."
        body="AI food tracking, progress goals, real communities, live rooms, and coach discovery in one Pro experience built for accountability."
        primaryHref="/pricing"
        primaryLabel="Start your 3-day Pro trial"
        secondaryHref="/ai"
        secondaryLabel="Explore AI tracking"
        note="No free tier · 3-day trial · cancel anytime"
        visual={<HeroVisual />}
      />

      <HowItWorks steps={onboardingSteps} />

      <section className="px-6 py-16">
        <div className="mx-auto max-w-6xl">
          <SectionHeader
            eyebrow="Core loop"
            title="A feedback loop for consistency"
            body="Veralify turns daily tracking into insight, support, accountability, and repeatable progress."
          />
          <div className="mt-12 flex flex-wrap items-stretch justify-center gap-2">
            {loop.map((step, index) => (
              <div key={step.label} className="flex items-center gap-2">
                <div className="flex w-32 flex-col items-center gap-2 rounded-vera-lg border border-vera-border bg-vera-surface px-3 py-4 text-center transition-colors duration-200 hover:border-vera-primary/40 sm:w-36">
                  <step.icon className="h-5 w-5 text-vera-primary" strokeWidth={1.75} />
                  <p className="text-xs font-semibold leading-tight">{step.label}</p>
                </div>
                {index < loop.length - 1 ? (
                  <ChevronRight
                    className="hidden h-4 w-4 shrink-0 text-vera-fg-subtle sm:block"
                    strokeWidth={2}
                  />
                ) : null}
              </div>
            ))}
          </div>
        </div>
      </section>

      <AlternatingFeatureRow
        feature={{
          icon: <Camera className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'AI food scan',
          title: 'Log meals from a photo, then verify the details.',
          body: 'The nutrition pipeline is provenance-first: AI helps identify food, the nutrition engine calculates estimates, and historical logs stay consistent over time.',
          points: [
            'Snap a photo — AI proposes the food and portions',
            'Confirm or correct before it saves to your log',
            'Calories, protein, carbs, and fat calculated deterministically',
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
          icon: <Radio className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: 'Live rooms',
          title: 'Show up together, in real time.',
          body: 'Voice and video rooms make accountability timely instead of buried in a feed — join a morning run club or a check-in before it starts.',
          points: [
            'Voice-first rooms with request-to-speak',
            'Scheduled community sessions and coach-hosted rooms',
            'Host moderation and clear speaking states',
          ],
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-coach-accent">
                <Radio className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">Live now</p>
              </div>
              <p className="mt-3 text-xl font-bold">Morning Run Club</p>
              <div className="mt-5 flex -space-x-2">
                {avatarTones.map((tone) => (
                  <div
                    key={tone}
                    className={`h-9 w-9 rounded-full border-2 border-vera-elevated ${tone}`}
                  />
                ))}
                <div className="flex h-9 w-9 items-center justify-center rounded-full border-2 border-vera-elevated bg-vera-surface text-xs font-semibold">
                  +6
                </div>
              </div>
              <p className="mt-4 text-sm text-vera-fg-muted">12 people live · tap to join</p>
            </GlassPanel>
          ),
        }}
      />

      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl">
          <SectionHeader
            eyebrow="Product"
            title="Built for tracking and accountability"
            body="The public launch focuses on the consumer Pro experience, with coach tools and marketplace discovery expanding the support layer."
          />
          <div className="mt-12">
            <FeatureGrid
              blocks={[
                {
                  eyebrow: 'Communities',
                  title: 'Join goal-aligned groups',
                  body: 'Find people working on similar nutrition, strength, endurance, or habit goals.',
                },
                {
                  eyebrow: 'Live rooms',
                  title: 'Show up together',
                  body: 'Voice and video rooms make accountability timely instead of buried in a feed.',
                },
                {
                  eyebrow: 'Coaches',
                  title: 'Discover human support',
                  body: 'Coach marketplace surfaces expert help when a member needs more personal guidance.',
                },
              ]}
            />
          </div>
        </div>
      </section>

      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl rounded-vera-2xl border border-vera-border bg-vera-surface p-8">
          <SectionHeader
            eyebrow="Pricing"
            title="One Pro subscription. Everything included."
            body="No free tier. A 3-day trial unlocks AI food logging, insights, groups, live rooms, progress analytics, and coach discovery."
          />
          <div className="mt-10 grid gap-4 md:grid-cols-3">
            {billingOptions.map((option) => (
              <div
                key={option.cadence}
                className={`rounded-vera-xl border p-5 transition-colors duration-200 ${
                  option.recommended
                    ? 'border-vera-primary bg-vera-bg-subtle shadow-[var(--vera-shadow-glow)]'
                    : 'border-vera-border bg-vera-bg-subtle'
                }`}
              >
                {option.recommended ? (
                  <p className="mb-2 text-xs font-bold uppercase tracking-wide text-vera-primary">
                    Best value
                  </p>
                ) : null}
                <p className="text-lg font-bold">{option.name}</p>
                <p className="mt-2 text-3xl font-black">{option.priceLabel}</p>
                <p className="mt-2 text-sm text-vera-fg-muted">{option.note}</p>
              </div>
            ))}
          </div>
          <div className="mt-8 text-center">
            <a className="btn-apple" href="/pricing">
              Compare billing options
            </a>
          </div>
        </div>
      </section>

      <FAQ
        title="Questions before you start"
        items={[
          {
            question: 'How does AI food logging actually work?',
            answer:
              'Take a photo of your meal — the AI proposes what it sees and estimated portions. You confirm or correct before anything saves, so your log stays accurate over time.',
          },
          {
            question: 'Is there a free tier?',
            answer:
              'No. Veralify Pro is a single subscription with a 3-day trial that unlocks everything — tracking, AI, communities, live rooms, and coach discovery.',
          },
          {
            question: "What if I'd rather work with a coach than track solo?",
            answer:
              'Coach discovery is built into Pro. Browse verified coaches, book a session, and pay securely — coaching complements tracking rather than replacing it.',
          },
          {
            question: 'Which platforms is Veralify on?',
            answer:
              'Veralify is available on the web and iOS today, sharing the same account, entitlements, and data.',
          },
        ]}
      />

      <CTASection
        title="Start with tracking. Stay for accountability."
        body="Veralify connects food logs, personal insights, communities, live rooms, and coaches into one transformation loop."
      />
    </MarketingShell>
  );
}
