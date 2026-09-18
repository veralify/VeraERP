import { billingOptions } from '@config/billing';
import type { Dictionary } from '@i18n/dictionaries';
import { Camera, Radio, UserCheck } from 'lucide-react';
import { HeroVisual } from './HeroVisual';
import {
  AlternatingFeatureRow,
  CTASection,
  Eyebrow,
  FAQ,
  GlassPanel,
  Hero,
  HowItWorks,
  MarketingShell,
  SectionHeader,
} from './SitePrimitives';

const avatarTones = [
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_35%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_25%,var(--vera-color-secondary)_20%)]',
  'bg-[color-mix(in_srgb,var(--vera-color-secondary)_35%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-coach-accent)_30%,transparent)]',
  'bg-[color-mix(in_srgb,var(--vera-color-primary)_20%,var(--vera-color-coach-accent)_20%)]',
  'bg-[color-mix(in_srgb,var(--vera-color-secondary)_25%,var(--vera-color-coach-accent)_15%)]',
];

export function HomePage({ t }: { t: Dictionary['marketing']['home'] }) {
  return (
    <MarketingShell>
      <Hero
        eyebrow={t.hero.eyebrow}
        title={t.hero.title}
        body={t.hero.body}
        primaryHref="/pricing"
        primaryLabel={t.hero.primaryCta}
        secondaryHref="/ai"
        secondaryLabel={t.hero.secondaryCta}
        note={t.hero.stats}
        visual={<HeroVisual />}
      />

      <HowItWorks
        eyebrow={t.howItWorks.eyebrow}
        title={t.howItWorks.title}
        steps={t.howItWorks.steps}
      />

      <section className="px-6 py-16">
        <div className="mx-auto max-w-3xl text-center">
          <Eyebrow>{t.whyItSticks.eyebrow}</Eyebrow>
          <p className="mt-5 text-xl leading-9 text-vera-fg-muted sm:text-2xl">
            {t.whyItSticks.body}
          </p>
        </div>
      </section>

      <AlternatingFeatureRow
        feature={{
          icon: <Camera className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: t.foodScan.eyebrow,
          title: t.foodScan.title,
          body: t.foodScan.body,
          points: t.foodScan.points,
          visual: (
            <GlassPanel>
              <div className="aspect-[4/3] rounded-vera-xl border border-vera-glass-border bg-[linear-gradient(135deg,color-mix(in_srgb,var(--vera-color-nutrition-calories)_25%,transparent),color-mix(in_srgb,var(--vera-color-nutrition-protein)_18%,transparent))] p-5">
                <div className="h-full rounded-vera-lg border border-vera-glass-border bg-vera-glass p-5">
                  <p className="text-sm text-vera-fg-muted">{t.foodScan.previewLabel}</p>
                  <p className="mt-4 text-4xl font-black tracking-tight">
                    {t.foodScan.previewHeading}
                  </p>
                  <div className="mt-8 grid grid-cols-2 gap-3 text-sm">
                    <span className="rounded-vera-md bg-vera-surface p-3">
                      {t.foodScan.calories}
                    </span>
                    <span className="rounded-vera-md bg-vera-surface p-3">
                      {t.foodScan.protein}
                    </span>
                    <span className="rounded-vera-md bg-vera-surface p-3">{t.foodScan.carbs}</span>
                    <span className="rounded-vera-md bg-vera-surface p-3">{t.foodScan.fat}</span>
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
          eyebrow: t.liveRooms.eyebrow,
          title: t.liveRooms.title,
          body: t.liveRooms.body,
          points: t.liveRooms.points,
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-coach-accent">
                <Radio className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">
                  {t.liveRooms.liveNow}
                </p>
              </div>
              <p className="mt-3 text-xl font-bold">{t.liveRooms.roomName}</p>
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
              <p className="mt-4 text-sm text-vera-fg-muted">{t.liveRooms.peopleLive}</p>
            </GlassPanel>
          ),
        }}
      />

      <AlternatingFeatureRow
        feature={{
          icon: <UserCheck className="h-5 w-5" strokeWidth={1.75} />,
          eyebrow: t.coach.eyebrow,
          title: t.coach.title,
          body: t.coach.body,
          points: t.coach.points,
          visual: (
            <GlassPanel>
              <div className="flex items-center gap-2 text-vera-coach-accent">
                <UserCheck className="h-4 w-4" strokeWidth={2} />
                <p className="text-xs font-semibold uppercase tracking-wide">{t.coach.badge}</p>
              </div>
              <p className="mt-3 text-xl font-bold">{t.coach.coachTitle}</p>
              <div className="mt-4 flex flex-wrap gap-2 text-xs">
                {t.coach.tags.map((tag) => (
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
        <div className="mx-auto max-w-6xl rounded-vera-2xl border border-vera-border bg-vera-surface p-8">
          <SectionHeader
            eyebrow={t.pricing.eyebrow}
            title={t.pricing.title}
            body={t.pricing.body}
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
                    {t.pricing.bestValue}
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
              {t.pricing.compareCta}
            </a>
          </div>
        </div>
      </section>

      <FAQ title={t.faq.title} items={t.faq.items} />

      <CTASection title={t.finalCta.title} body={t.finalCta.body} />
    </MarketingShell>
  );
}
