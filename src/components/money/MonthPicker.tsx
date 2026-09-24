import { inputClass } from '@components/member/DashboardPrimitives';
import { monthLabel, shiftMonth } from '@lib/money/spending';
import { ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * Month selector driven by the `?month=YYYY-MM` URL param, so a month is
 * linkable and works without JavaScript: previous/next are plain links and
 * the picker is a GET form. `keep` carries the page's other params along.
 */
export function MonthPicker({
  basePath,
  month,
  maxMonth,
  keep = {},
}: {
  basePath: string;
  month: string;
  /** Latest selectable month (the current one); "next" stops there. */
  maxMonth: string;
  keep?: Record<string, string | undefined>;
}) {
  const href = (target: string) => {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(keep)) if (value) params.set(key, value);
    params.set('month', target);
    return `${basePath}?${params.toString()}`;
  };
  const previous = shiftMonth(month, -1);
  const next = shiftMonth(month, 1);
  const linkClass =
    'inline-flex h-11 w-11 items-center justify-center rounded-full border border-vera-border bg-vera-surface text-vera-fg transition-colors hover:bg-vera-surface-muted';

  return (
    <nav className="flex items-center gap-2" aria-label="Choose month">
      <a
        className={linkClass}
        href={href(previous)}
        aria-label={`Previous month, ${monthLabel(previous)}`}
      >
        <ChevronLeft className="h-4 w-4" strokeWidth={2} />
      </a>
      <form method="get" action={basePath} className="flex items-center gap-2">
        {Object.entries(keep).map(([key, value]) =>
          value ? <input key={key} type="hidden" name={key} value={value} /> : null,
        )}
        <label className="sr-only" htmlFor="month-picker">
          Month
        </label>
        <input
          id="month-picker"
          className={`${inputClass} w-40`}
          type="month"
          name="month"
          defaultValue={month}
          max={maxMonth}
          required
        />
        <button type="submit" className="btn-apple-secondary">
          Show
        </button>
      </form>
      {month < maxMonth ? (
        <a className={linkClass} href={href(next)} aria-label={`Next month, ${monthLabel(next)}`}>
          <ChevronRight className="h-4 w-4" strokeWidth={2} />
        </a>
      ) : (
        <span className={`${linkClass} pointer-events-none opacity-40`} aria-hidden="true">
          <ChevronRight className="h-4 w-4" strokeWidth={2} />
        </span>
      )}
    </nav>
  );
}
