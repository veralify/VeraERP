export function EmptyState({
  title,
  body,
  ctaHref,
  ctaLabel,
}: {
  title: string;
  body: string;
  ctaHref?: string;
  ctaLabel?: string;
}) {
  return (
    <section className="rounded-vera-2xl border border-vera-border bg-vera-surface p-8 text-center shadow-[var(--vera-shadow-sm)]">
      <div
        className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-vera-surface-muted text-2xl"
        aria-hidden="true"
      >
        •
      </div>
      <h2 className="mt-5 text-2xl font-bold tracking-tight">{title}</h2>
      <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-vera-fg-muted">{body}</p>
      {ctaHref && ctaLabel ? (
        <a className="btn-apple mt-6" href={ctaHref}>
          {ctaLabel}
        </a>
      ) : null}
    </section>
  );
}
