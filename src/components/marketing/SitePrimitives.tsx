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
  /** Small trust/disclosure line under the CTAs, e.g. "No free tier · cancel anytime". */
  note?: string;
  /** Optional right-column visual (homepage only) — switches to a two-column layout at lg. */
  visual?: ReactNode;
}) {
  return (
    <section className="relative isolate overflow-hidden px-6 py-24 sm:py-32">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,color-mix(in_srgb,var(--vera-color-primary)_24%,transparent),transparent_34rem),radial-gradient(circle_at_bottom_right,color-mix(in_srgb,var(--vera-color-secondary)_18%,transparent),transparent_30rem)]" />
      <div
        className={`mx-auto max-w-6xl ${visual ? 'grid gap-16 lg:grid-cols-[1.1fr_0.9fr] lg:items-center' : ''}`}
      >
        <Reveal variants={fadeUp}>
          <p className="text-sm font-semibold uppercase tracking-[0.18em] text-vera-primary">
            {eyebrow}
          </p>
          <h1 className="mt-5 max-w-4xl text-5xl font-black leading-[0.96] tracking-[-0.06em] sm:text-7xl">
            {title}
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-8 text-vera-fg-muted sm:text-xl">{body}</p>
          <div className="mt-10 flex flex-wrap gap-3">
            <a className="btn-apple" href={primaryHref}>
              {primaryLabel}
            </a>
            {secondaryHref && secondaryLabel ? (
              <a className="btn-apple-secondary" href={secondaryHref}>
                {secondaryLabel}
              </a>
            ) : null}
          </div>
          {note ? <p className="mt-4 text-sm text-vera-fg-subtle">{note}</p> : null}
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
          <div className="inline-flex h-11 w-11 items-center justify-center rounded-vera-md bg-vera-primary/15 text-vera-primary">
            {feature.icon}
          </div>
          <p className="mt-5 text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
            {feature.eyebrow}
          </p>
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
      <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
        {eyebrow}
      </p>
      <h2 className="mt-3 text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
      {body ? (
        <p className="mt-4 text-base leading-7 text-vera-fg-muted sm:text-lg">{body}</p>
      ) : null}
    </div>
  );
}

export type HowItWorksStep = { title: string; body: string };

/** Bold numbered onboarding steps — the first-run path, distinct from the ongoing core loop. */
export function HowItWorks({ steps }: { steps: HowItWorksStep[] }) {
  return (
    <section className="px-6 py-20">
      <div className="mx-auto max-w-6xl">
        <SectionHeader
          eyebrow="How it works"
          title="From download to your first log in under a minute."
        />
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
          className="rounded-vera-xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] transition-[transform,box-shadow,border-color] duration-200 ease-[var(--vera-ease-standard)] hover:-translate-y-1 hover:border-vera-primary/40 hover:shadow-[var(--vera-shadow-md)]"
        >
          <p className="text-sm font-semibold text-vera-primary">{block.eyebrow}</p>
          <h3 className="mt-3 text-xl font-bold tracking-tight">{block.title}</h3>
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
        className="mx-auto max-w-5xl rounded-vera-2xl border border-vera-glass-border bg-vera-glass p-8 text-center shadow-[var(--vera-shadow-lg)] sm:p-12"
        variants={scaleIn}
      >
        <h2 className="text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
        <p className="mx-auto mt-4 max-w-2xl text-vera-fg-muted">{body}</p>
        <a className="btn-apple mt-8" href={href}>
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
