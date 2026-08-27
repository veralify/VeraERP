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
}: {
  eyebrow: string;
  title: string;
  body: string;
  primaryHref?: string;
  primaryLabel?: string;
  secondaryHref?: string;
  secondaryLabel?: string;
}) {
  return (
    <section className="relative isolate overflow-hidden px-6 py-24 sm:py-32">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,color-mix(in_srgb,var(--vera-color-primary)_24%,transparent),transparent_34rem),radial-gradient(circle_at_bottom_right,color-mix(in_srgb,var(--vera-color-secondary)_18%,transparent),transparent_30rem)]" />
      <div className="mx-auto max-w-6xl">
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
      </div>
    </section>
  );
}

export function SectionHeader({
  eyebrow,
  title,
  body,
}: {
  eyebrow: string;
  title: string;
  body: string;
}) {
  return (
    <div className="mx-auto max-w-3xl text-center">
      <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
        {eyebrow}
      </p>
      <h2 className="mt-3 text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
      <p className="mt-4 text-base leading-7 text-vera-fg-muted sm:text-lg">{body}</p>
    </div>
  );
}

export function FeatureGrid({ blocks }: { blocks: FeatureBlock[] }) {
  return (
    <div className="grid gap-5 md:grid-cols-3">
      {blocks.map((block) => (
        <article
          key={block.title}
          className="rounded-vera-xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)]"
        >
          <p className="text-sm font-semibold text-vera-primary">{block.eyebrow}</p>
          <h3 className="mt-3 text-xl font-bold tracking-tight">{block.title}</h3>
          <p className="mt-3 text-sm leading-6 text-vera-fg-muted">{block.body}</p>
        </article>
      ))}
    </div>
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
      <div className="mx-auto max-w-5xl rounded-vera-2xl border border-vera-glass-border bg-vera-glass p-8 text-center shadow-[var(--vera-shadow-lg)] sm:p-12">
        <h2 className="text-3xl font-bold tracking-tight sm:text-5xl">{title}</h2>
        <p className="mx-auto mt-4 max-w-2xl text-vera-fg-muted">{body}</p>
        <a className="btn-apple mt-8" href={href}>
          {label}
        </a>
      </div>
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
