import { billingOptions } from '@config/billing';
import { CTASection, FeatureGrid, Hero, MarketingShell, SectionHeader } from './SitePrimitives';

const loop = [
  'Track',
  'AI understands',
  'Personal insight',
  'Connect',
  'Community or coach',
  'Accountability',
  'Transform',
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
      />
      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl">
          <SectionHeader
            eyebrow="Core loop"
            title="A feedback loop for consistency"
            body="Veralify turns daily tracking into insight, support, accountability, and repeatable progress."
          />
          <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-7">
            {loop.map((step, index) => (
              <div
                key={step}
                className="rounded-vera-lg border border-vera-border bg-vera-surface p-4"
              >
                <p className="text-xs font-semibold text-vera-fg-subtle">
                  {String(index + 1).padStart(2, '0')}
                </p>
                <p className="mt-2 font-bold">{step}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="px-6 py-20">
        <div className="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[1fr_0.9fr] lg:items-center">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
              AI food scan
            </p>
            <h2 className="mt-3 text-3xl font-bold tracking-tight sm:text-5xl">
              Log meals from a photo, then verify the details.
            </h2>
            <p className="mt-5 text-vera-fg-muted">
              The nutrition pipeline is provenance-first: AI helps identify food, the nutrition
              engine calculates estimates, and historical logs stay consistent over time.
            </p>
          </div>
          <div className="rounded-vera-2xl border border-vera-border bg-vera-elevated p-6 shadow-[var(--vera-shadow-lg)]">
            <div className="aspect-[4/3] rounded-vera-xl border border-vera-glass-border bg-[linear-gradient(135deg,color-mix(in_srgb,var(--vera-color-calories)_25%,transparent),color-mix(in_srgb,var(--vera-color-protein)_18%,transparent))] p-5">
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
          </div>
        </div>
      </section>
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
                className="rounded-vera-xl border border-vera-border bg-vera-bg-subtle p-5"
              >
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
      <CTASection
        title="Start with tracking. Stay for accountability."
        body="Veralify connects food logs, personal insights, communities, live rooms, and coaches into one transformation loop."
      />
    </MarketingShell>
  );
}
