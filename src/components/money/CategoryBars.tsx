import { formatCurrency } from '@lib/money/format';
import styles from './charts.module.css';

export interface CategoryBarDatum {
  key: string;
  label: string;
  total: number;
  previous: number;
}

/**
 * Spending by category as horizontal bars — one series, so one hue
 * (categorical slot 1) for every bar; the category name, not the colour,
 * carries identity. Each value sits at its bar's tip; share of the month and
 * last month's figure are in the hover tooltip and in the table view,
 * so nothing is readable only by hovering.
 *
 * Server component: the tooltip is CSS-only (group-hover). It is hidden from
 * assistive tech and the rows aren't tab stops because the table view below
 * carries the same figures in an accessible form.
 */
export function CategoryBars({
  data,
  currency,
  monthLabel,
  previousLabel,
}: {
  data: CategoryBarDatum[];
  currency: string;
  monthLabel: string;
  previousLabel: string;
}) {
  const max = Math.max(...data.map((d) => d.total), 0);
  const sum = data.reduce((s, d) => s + d.total, 0);
  const share = (value: number) => (sum > 0 ? Math.round((value / sum) * 100) : 0);

  return (
    <div className={styles.root}>
      <ul className="mt-4 grid gap-1" aria-label={`Spending by category, ${monthLabel}`}>
        {data.map((d) => {
          const ratio = max > 0 ? d.total / max : 0;
          const value = formatCurrency(d.total, currency);
          return (
            <li key={d.key}>
              <div
                className={`${styles.barRow} group relative grid grid-cols-[minmax(0,8.5rem)_1fr] items-center gap-3 rounded-vera-md px-2 py-1.5 hover:bg-vera-surface-muted`}
              >
                <span className="truncate text-sm text-vera-fg-muted">{d.label}</span>
                <span className="flex min-w-0 items-center gap-2">
                  <span
                    className={`${styles.bar} block h-3.5 flex-none`}
                    // 5.5rem is kept free for the value label at the tip of the longest bar.
                    style={{ width: `max(2px, calc((100% - 5.5rem) * ${ratio.toFixed(4)}))` }}
                    aria-hidden="true"
                  />
                  <span className="flex-none text-sm font-semibold tabular-nums">{value}</span>
                </span>
                <span
                  aria-hidden="true"
                  className="pointer-events-none absolute top-full left-2 z-10 mt-1 hidden min-w-48 rounded-vera-md border border-vera-border bg-vera-elevated p-3 text-xs shadow-[var(--vera-shadow-md)] group-hover:block"
                >
                  <span className="block text-sm font-bold text-vera-fg">{value}</span>
                  <span className="block text-vera-fg-muted">
                    {d.label} · {share(d.total)}% of {monthLabel}
                  </span>
                  <span className="mt-1 block text-vera-fg-muted">
                    {previousLabel}: {formatCurrency(d.previous, currency)}
                  </span>
                </span>
              </div>
            </li>
          );
        })}
      </ul>
      <details className="mt-4 text-sm">
        <summary className="cursor-pointer text-vera-fg-muted hover:text-vera-fg">
          Show as table
        </summary>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-left tabular-nums">
            <thead className="text-vera-fg-muted">
              <tr>
                <th className="py-2 pr-3 font-medium">Category</th>
                <th className="py-2 pr-3 text-right font-medium">{monthLabel}</th>
                <th className="py-2 pr-3 text-right font-medium">Share</th>
                <th className="py-2 text-right font-medium">{previousLabel}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-vera-border">
              {data.map((d) => (
                <tr key={d.key}>
                  <td className="py-2 pr-3">{d.label}</td>
                  <td className="py-2 pr-3 text-right">{formatCurrency(d.total, currency)}</td>
                  <td className="py-2 pr-3 text-right">{share(d.total)}%</td>
                  <td className="py-2 text-right">{formatCurrency(d.previous, currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </div>
  );
}
