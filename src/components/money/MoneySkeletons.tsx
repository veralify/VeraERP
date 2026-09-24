import { Skeleton, SkeletonList } from '@components/generic/Skeleton';

/**
 * Route-skeleton compositions for the money feature's `loading.tsx` files,
 * built from the shared `Skeleton`/`SkeletonList` primitives and shaped to
 * match each route's real layout (see states.md: "shape matching final
 * component") so navigation doesn't cause layout shift.
 */

function FormSkeleton() {
  return (
    <div className="rounded-vera-2xl border border-vera-border bg-vera-surface p-6">
      <Skeleton className="h-6 w-2/5" />
      <div className="mt-5 grid gap-4">
        <Skeleton className="h-11 w-full" />
        <Skeleton className="h-11 w-full" />
        <Skeleton className="h-11 w-full" />
        <Skeleton className="h-11 w-1/3" />
      </div>
    </div>
  );
}

function ListCardSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)]">
      <Skeleton className="h-6 w-1/3" />
      <SkeletonList count={rows} className="mt-4" />
    </div>
  );
}

export function ListPageSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <main className="px-4 py-8 lg:px-8">
      <Skeleton className="h-4 w-16" />
      <Skeleton className="mt-2 h-9 w-72" />
      <Skeleton className="mt-3 h-4 w-full max-w-xl" />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <ListCardSkeleton rows={rows} />
        <FormSkeleton />
      </div>
    </main>
  );
}

export function DebtsPageSkeleton() {
  return (
    <main className="px-4 py-8 lg:px-8">
      <Skeleton className="h-4 w-16" />
      <Skeleton className="mt-2 h-9 w-72" />
      <Skeleton className="mt-3 h-4 w-full max-w-xl" />
      <div className="mt-4 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <ListCardSkeleton rows={3} />
          <div className="rounded-vera-2xl border border-vera-border bg-vera-surface p-6">
            <Skeleton className="h-6 w-1/3" />
            <div className="mt-5 grid grid-cols-4 gap-4">
              <Skeleton className="h-10" />
              <Skeleton className="h-10" />
              <Skeleton className="h-10" />
              <Skeleton className="h-10" />
            </div>
            <Skeleton className="mt-6 h-40 w-full" />
          </div>
        </div>
        <div className="space-y-6">
          <FormSkeleton />
          <FormSkeleton />
        </div>
      </div>
    </main>
  );
}

function ChartCardSkeleton({ height = 'h-56' }: { height?: string }) {
  return (
    <div className="rounded-vera-2xl border border-vera-border bg-vera-surface p-6">
      <Skeleton className="h-6 w-1/3" />
      <Skeleton className="mt-2 h-4 w-1/2" />
      <Skeleton className={`mt-5 w-full ${height}`} />
    </div>
  );
}

function StatRowSkeleton() {
  return (
    <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: 4 }, (_, i) => (
        // biome-ignore lint/suspicious/noArrayIndexKey: static placeholder list
        <div key={i} className="rounded-vera-xl border border-vera-border bg-vera-surface p-5">
          <Skeleton className="h-4 w-1/2" />
          <Skeleton className="mt-3 h-8 w-2/3" />
          <Skeleton className="mt-2 h-3 w-3/4" />
        </div>
      ))}
    </div>
  );
}

/** Spending dashboard: KPI row, category bars + trend, budgets + receipts. */
export function OverviewSkeleton() {
  return (
    <main className="px-4 py-8 lg:px-8">
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <Skeleton className="h-4 w-16" />
          <Skeleton className="mt-2 h-9 w-96 max-w-full" />
          <Skeleton className="mt-3 h-4 w-full max-w-xl" />
        </div>
        <Skeleton className="h-11 w-80 max-w-full" />
      </div>
      <StatRowSkeleton />
      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_420px]">
        <div className="space-y-6">
          <ChartCardSkeleton height="h-48" />
          <ChartCardSkeleton height="h-60" />
        </div>
        <div className="space-y-6">
          <ListCardSkeleton rows={3} />
          <ListCardSkeleton rows={4} />
        </div>
      </div>
    </main>
  );
}

/** Receipts: filter row, then a list of thumbnail rows. */
export function ReceiptsPageSkeleton() {
  return (
    <main className="px-4 py-8 lg:px-8">
      <Skeleton className="h-4 w-16" />
      <Skeleton className="mt-2 h-9 w-72" />
      <Skeleton className="mt-3 h-4 w-full max-w-xl" />
      <div className="mt-8 flex flex-wrap gap-3">
        {Array.from({ length: 4 }, (_, i) => (
          // biome-ignore lint/suspicious/noArrayIndexKey: static placeholder list
          <Skeleton key={i} className="h-11 w-44" />
        ))}
      </div>
      <div className="mt-4 rounded-vera-2xl border border-vera-border bg-vera-surface p-6">
        <Skeleton className="h-6 w-1/4" />
        {Array.from({ length: 3 }, (_, i) => (
          // biome-ignore lint/suspicious/noArrayIndexKey: static placeholder list
          <div key={i} className="mt-5 flex gap-4">
            <Skeleton className="h-32 w-24" />
            <div className="flex-1">
              <Skeleton className="h-5 w-1/3" />
              <Skeleton className="mt-2 h-4 w-1/2" />
              <Skeleton className="mt-4 h-4 w-2/3" />
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
