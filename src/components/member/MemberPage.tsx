import { EmptyState } from './EmptyState';

export function MemberPage({
  eyebrow,
  title,
  body,
  emptyTitle,
  emptyBody,
  ctaHref,
  ctaLabel,
}: {
  eyebrow: string;
  title: string;
  body: string;
  emptyTitle: string;
  emptyBody: string;
  ctaHref?: string;
  ctaLabel?: string;
}) {
  return (
    <main className="px-4 py-8 lg:px-8">
      <section className="mb-8">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
          {eyebrow}
        </p>
        <h1 className="mt-2 text-3xl font-black tracking-tight sm:text-5xl">{title}</h1>
        <p className="mt-3 max-w-2xl text-vera-fg-muted">{body}</p>
      </section>
      <EmptyState title={emptyTitle} body={emptyBody} ctaHref={ctaHref} ctaLabel={ctaLabel} />
    </main>
  );
}
