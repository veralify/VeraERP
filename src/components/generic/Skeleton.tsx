/**
 * Loading placeholder. Shape-match the real content by passing className
 * (height/width/radius) — see design-system/veralify/components/states.md
 * `VeraSkeleton`: "shape matching final component".
 *
 * Pure CSS (no client boundary needed) so it can be used directly from
 * Suspense fallbacks and server components. Shimmer is gated behind
 * `motion-safe` so `prefers-reduced-motion: reduce` gets a static block.
 */
export function Skeleton({ className = '' }: { className?: string }) {
  return (
    <div
      aria-hidden="true"
      className={`motion-safe:animate-pulse rounded-vera-md bg-vera-surface-muted ${className}`}
    />
  );
}

/** A single text line skeleton, e.g. for titles/labels. */
export function SkeletonText({
  className = '',
  width = 'w-3/4',
}: {
  className?: string;
  width?: string;
}) {
  return <Skeleton className={`h-4 ${width} ${className}`} />;
}

/** Card-shaped skeleton matching the `Card` primitive's padding/radius. */
export function SkeletonCard({ className = '' }: { className?: string }) {
  return (
    <div
      className={`rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] ${className}`}
    >
      <Skeleton className="h-3 w-24" />
      <Skeleton className="mt-4 h-6 w-2/3" />
      <Skeleton className="mt-3 h-4 w-full" />
      <Skeleton className="mt-2 h-4 w-5/6" />
      <div className="mt-5 grid grid-cols-2 gap-3">
        <Skeleton className="h-10" />
        <Skeleton className="h-10" />
      </div>
    </div>
  );
}

/** A grid of `SkeletonCard`s, for discovery/list fallbacks. */
export function SkeletonGrid({
  count = 6,
  className = '',
}: {
  count?: number;
  className?: string;
}) {
  return (
    <div className={`grid gap-5 md:grid-cols-2 xl:grid-cols-3 ${className}`}>
      {Array.from({ length: count }, (_, i) => (
        // biome-ignore lint/suspicious/noArrayIndexKey: static placeholder list, order never changes
        <SkeletonCard key={i} />
      ))}
    </div>
  );
}

/** A single list-row skeleton, e.g. for bookings/sessions/clients rows. */
export function SkeletonRow({ className = '' }: { className?: string }) {
  return (
    <div className={`flex items-center justify-between gap-3 py-4 ${className}`}>
      <div className="flex-1">
        <Skeleton className="h-4 w-1/3" />
        <Skeleton className="mt-2 h-3 w-1/2" />
      </div>
      <Skeleton className="h-6 w-20 rounded-full" />
    </div>
  );
}

export function SkeletonList({
  count = 3,
  className = '',
}: {
  count?: number;
  className?: string;
}) {
  return (
    <div className={`divide-y divide-vera-border ${className}`}>
      {Array.from({ length: count }, (_, i) => (
        // biome-ignore lint/suspicious/noArrayIndexKey: static placeholder list, order never changes
        <SkeletonRow key={i} />
      ))}
    </div>
  );
}
