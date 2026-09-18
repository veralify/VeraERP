import { Reveal, StaggerGroup, StaggerItem } from '@components/generic/Motion';
import { fadeUp, scaleIn } from '@lib/motion/variants';
import { Check } from 'lucide-react';
import type { ReactNode } from 'react';

export type FeatureBlock = {
  eyebrow: string;
  title: string;
  body: string;
};

export function MarketingShell({ children }: { children: ReactNode }) {
  return <main className="bg-vera-bg text-vera-fg">{children}</main>;
}

/** A slanted "starting block" tick — the small athletic accent that precedes every eyebrow label. */
function EyebrowTick() {
  return (
    <span
      aria-hidden="true"
      className="inline-block h-3 w-1.5 shrink-0 -skew-x-[20deg] bg-vera-secondary align-middle"
    />
  );
}

export function Eyebrow({ children }: { children: ReactNode }) {
  return (
    <p className="flex items-center gap-2 text-sm font-bold uppercase tracking-[0.18em] text-vera-primary">
      <EyebrowTick />
      {children}
    </p>
  );
}

export function Hero({
  eyebrow,
  title,
  body,
  primaryHref = '/pricing',
  primaryLabel = 'Get started',
  secondaryHref,
  secondaryLabel,
  note,
  visual,
}: {
  eyebrow: string;
  title: string;
  body: string;
  primaryHref?: string;
  primaryLabel?: string;
  secondaryHref?: string;
  secondaryLabel?: string;
  /** Scoreboard-style facts under the CTAs, e.g. ["3-day trial", "No free tier"]. */
  note?: string[];
  /** Optional right-column visual (homepage only) — switches to a two-column layout at lg. */
  visual?: ReactNode;
}) {
  return (
    <section
      className="relative isolate overflow-hidden px-6 pb-28 pt-24 sm:pb-36 sm:pt-32"
      style={{ clipPath: 'polygon(0 0, 100% 0, 100% calc(100% - 3.5rem), 0 100%)' }}
    >
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,color-mix(in_srgb,var(--vera-color-primary)_24%,transparent),transparent_34rem),radial-gradient(circle_at_bottom_right,color-mix(in_srgb,var(--vera-color-secondary)_18%,transparent),transparent_30rem)]" />
      {/* Speed lines — a sweep of angled strokes suggesting motion, fading out to the right. */}
      <div
        aria-hidden="true"
        className="absolute inset-y-0 left-0 -z-10 hidden w-2/3 opacity-[0.07] sm:block"
        style={{
          backgroundImage:
            'repeating-linear-gradient(115deg, var(--vera-color-fg) 0px, var(--vera-color-fg) 2px, transparent 2px, transparent 34px)',
          maskImage: 'linear-gradient(to right, black, transparent)',
        }}
      />
      <div
        className={`mx-auto max-w-6xl ${visual ? 'grid gap-16 lg:grid-cols-[1.1fr_0.9fr] lg:items-center' : ''}`}
      >
        <Reveal variants={fadeUp}>
          <Eyebrow>{eyebrow}</Eyebrow>
          <h1 className="mt-5 max-w-4xl text-5xl font-black uppercase leading-[0.92] tracking-[-0.04em] sm:text-7xl">
            {title}
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-8 text-vera-fg-muted sm:text-xl">{body}</p>
          <div className="mt-10 flex flex-wrap gap-3">
            <a
              className="btn-apple font-semibold shadow-[var(--vera-shadow-glow)] transition-transform hover:scale-[1.04] active:scale-95"
              href={primaryHref}
            >
              {primaryLabel}
            </a>
            {secondaryHref && secondaryLabel ? (
              <a className="btn-apple-secondary" href={secondaryHref}>
                {secondaryLabel}
              </a>
            ) : null}
          </div>
          {note ? <StatStrip items={note} /> : null}
        </Reveal>
        {visual ? (
          <Reveal variants={scaleIn} className="hidden lg:block">
            {visual}
          </Reveal>
        ) : null}
      </div>
    </section>
  );
}

/** Scoreboard-style facts row — bold, uppercase, tabular. Only ever real product facts, never fabricated stats. */
export function StatStrip({ items }: { items: string[] }) {
  return (
    <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-3">
      {items.map((item, index) => (
        <span key={item} className="flex items-center gap-6">
          {index > 0 ? <span className="h-6 w-px bg-vera-border" aria-hidden="true" /> : null}
          <span className="text-xs font-bold uppercase tracking-widest text-vera-fg-subtle [font-variant-numeric:tabular-nums]">
            {item}
          </span>
        </span>
      ))}
    </div>
  );
}

export type AlternatingFeature = {
  icon: ReactNode;
  eyebrow: string;
  title: string;
  body: string;
  points: string[];
  visual: ReactNode;
};

/** A left/right-alternating deep-dive section — used on /features and the homepage. */
export function AlternatingFeatureRow({
  feature,
  reverse,
}: {
  feature: AlternatingFeature;
  reverse?: boolean;
}) {
  return (
    <div className="mx-auto max-w-6xl px-6 py-16">
      <div
        className={`grid items-center gap-12 lg:grid-cols-2 ${reverse ? 'lg:[&>*:first-child]:order-2' : ''}`}
      >
        <Reveal variants={fadeUp}>
          <div className="inline-flex h-12 w-12 -skew-x-6 items-center justify-center rounded-vera-md bg-[linear-gradient(135deg,color-mix(in_srgb,var(--vera-color-primary)_28%,transparent),color-mix(in_srgb,var(--vera-color-secondary)_22%,transparent))] text-vera-primary">
            <span className="skew-x-6">{feature.icon}</span>
          </div>
          <div className="mt-5">
            <Eyebrow>{feature.eyebrow}</Eyebrow>
          </div>
          <h2 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">{feature.title}</h2>
          <p className="mt-4 text-vera-fg-muted">{feature.body}</p>
          <ul className="mt-6 space-y-3">
            {feature.points.map((point) => (
              <li key={point} className="flex items-start gap-2.5 text-sm">
                <Check className="mt-0.5 h-4 w-4 shrink-0 text-vera-success" strokeWidth={2.5} />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </Reveal>
        <Reveal variants={scaleIn}>{feature.visual}</Reveal>
      </div>
    </div>
  );
}

/** A generic glass panel used as the visual half of an AlternatingFeatureRow. */
export function GlassPanel({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-vera-2xl border border-vera-border bg-vera-elevated p-6 shadow-[var(--vera-shadow-lg)]">
      {children}
    </div>
  );
}

export function SectionHeader({
  eyebrow,
  title,
  body,
}: {
  eyebrow: string;
  title: string;
  body?: string;
}) {
  return (
    <div className="mx-auto max-w-3xl text-center">
      <div className="flex justify-center">
        <Eyebrow>{eyebrow}</Eyebrow>
      </div>
      <h2 className="mt-3 text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
      {body ? (
        <p className="mt-4 text-base leading-7 text-vera-fg-muted sm:text-lg">{body}</p>
      ) : null}
    </div>
  );
}

export type HowItWorksStep = { title: string; body: string };

/** Bold numbered onboarding steps — the first-run path, distinct from the ongoing core loop. */
export function HowItWorks({
  eyebrow,
  title,
  steps,
}: {
  eyebrow: string;
  title: string;
  steps: HowItWorksStep[];
}) {
  return (
    <section className="px-6 py-20">
      <div className="mx-auto max-w-6xl">
        <SectionHeader eyebrow={eyebrow} title={title} />
        <StaggerGroup className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, index) => (
            <StaggerItem key={step.title} className="relative">
              <p className="text-6xl font-black tracking-tighter text-vera-primary/25">
                {String(index + 1).padStart(2, '0')}
              </p>
              <h3 className="-mt-4 text-xl font-bold tracking-tight">{step.title}</h3>
              <p className="mt-2 text-sm leading-6 text-vera-fg-muted">{step.body}</p>
            </StaggerItem>
          ))}
        </StaggerGroup>
      </div>
    </section>
  );
}

export function FeatureGrid({ blocks }: { blocks: FeatureBlock[] }) {
  return (
    <StaggerGroup className="grid gap-5 md:grid-cols-3">
      {blocks.map((block) => (
        <StaggerItem
          key={block.title}
          as="article"
          className="group rounded-vera-xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] transition-[transform,box-shadow,border-color] duration-200 ease-[var(--vera-ease-standard)] hover:-translate-y-1.5 hover:border-vera-secondary/50 hover:shadow-[var(--vera-shadow-md)]"
        >
          <p className="text-xs font-bold uppercase tracking-widest text-vera-secondary">
            {block.eyebrow}
          </p>
          <h3 className="mt-3 text-xl font-bold tracking-tight transition-colors group-hover:text-vera-primary">
            {block.title}
          </h3>
          <p className="mt-3 text-sm leading-6 text-vera-fg-muted">{block.body}</p>
        </StaggerItem>
      ))}
    </StaggerGroup>
  );
}

export type FAQItem = { question: string; answer: string };

/**
 * Native `<details>` accordion — no client JS/state needed. Emits FAQPage
 * JSON-LD alongside the visible copy so the same content serves SEO too.
 */
export function FAQ({
  eyebrow = 'FAQ',
  title,
  items,
}: {
  eyebrow?: string;
  title: string;
  items: FAQItem[];
}) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: { '@type': 'Answer', text: item.answer },
    })),
  };
  return (
    <section className="px-6 py-20">
      <script
        type="application/ld+json"
        // biome-ignore lint/security/noDangerouslySetInnerHtml: schema is JSON.stringify of developer-authored `items` copy, not user input or raw HTML.
        dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
      />
      <div className="mx-auto max-w-3xl">
        <SectionHeader eyebrow={eyebrow} title={title} />
        <div className="mt-10 space-y-3">
          {items.map((item) => (
            <details
              key={item.question}
              className="group rounded-vera-xl border border-vera-border bg-vera-surface px-5 py-4 open:bg-vera-bg-subtle"
            >
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold marker:content-none">
                {item.question}
                <span className="shrink-0 text-vera-fg-subtle transition-transform duration-200 group-open:rotate-45">
                  +
                </span>
              </summary>
              <p className="mt-3 text-sm leading-6 text-vera-fg-muted">{item.answer}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

export function CTASection({
  title,
  body,
  href = '/pricing',
  label = 'Start your 3-day Pro trial',
}: {
  title: string;
  body: string;
  href?: string;
  label?: string;
}) {
  return (
    <section className="px-6 py-20">
      <Reveal
        className="relative mx-auto max-w-5xl overflow-hidden rounded-vera-2xl border border-vera-glass-border bg-vera-glass p-8 text-center shadow-[var(--vera-shadow-lg)] sm:p-12"
        variants={scaleIn}
      >
        <div
          aria-hidden="true"
          className="absolute inset-x-0 top-0 h-1 bg-[linear-gradient(90deg,var(--vera-color-primary),var(--vera-color-secondary))]"
        />
        <h2 className="text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
        <p className="mx-auto mt-4 max-w-2xl text-vera-fg-muted">{body}</p>
        <a
          className="btn-apple mt-8 font-semibold shadow-[var(--vera-shadow-glow)] transition-transform hover:scale-[1.04] active:scale-95"
          href={href}
        >
          {label}
        </a>
      </Reveal>
    </section>
  );
}

export function FeaturePage({
  eyebrow,
  title,
  body,
  blocks,
}: {
  eyebrow: string;
  title: string;
  body: string;
  blocks: FeatureBlock[];
}) {
  return (
    <MarketingShell>
      <Hero
        eyebrow={eyebrow}
        title={title}
        body={body}
        secondaryHref="/pricing"
        secondaryLabel="View pricing"
      />
      <section className="px-6 py-20">
        <div className="mx-auto max-w-6xl">
          <FeatureGrid blocks={blocks} />
        </div>
      </section>
      <CTASection
        title="Everything unlocks with Veralify Pro."
        body="Start with a 3-day trial, then keep tracking, connecting, and transforming with one subscription."
      />
    </MarketingShell>
  );
}
