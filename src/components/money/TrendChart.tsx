'use client';

import { type KeyboardEvent, type PointerEvent, useEffect, useRef, useState } from 'react';
import styles from './charts.module.css';

export interface TrendDatum {
  month: string;
  /** Axis label, e.g. "Sep". */
  short: string;
  /** Tooltip/table label, e.g. "September 2026". */
  long: string;
  spending: number;
  income: number;
  /**
   * Display strings, formatted on the server. Node's and the browser's ICU
   * data disagree on some currency formats (compact "€0" vs "€0.0"), which
   * would make the hydrated text differ from the server render.
   */
  spendingText: string;
  incomeText: string;
  netText: string;
  spendingShort: string;
  incomeShort: string;
}

export interface TrendTick {
  value: number;
  label: string;
}

const SERIES = [
  { key: 'spending', label: 'Spending', color: 'var(--chart-series-1)' },
  { key: 'income', label: 'Income', color: 'var(--chart-series-2)' },
] as const;

const PLOT_HEIGHT = 200;
const MARGIN = { top: 12, right: 76, bottom: 28, left: 56 };

/**
 * Twelve months of home-currency spending and income as two 2px lines on one
 * axis (same unit, so one scale — never two). Hovering, or arrowing with the
 * chart focused, snaps a crosshair to the nearest month and lists both
 * values; the same numbers are in the table view below, so the tooltip only
 * enhances. Width is measured so text stays at its real size on any screen.
 */
export function TrendChart({
  data,
  ticks,
  currency,
}: {
  data: TrendDatum[];
  /** From `niceTicks`, labelled on the server; the last one is the axis top. */
  ticks: TrendTick[];
  currency: string;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(640);
  const [active, setActive] = useState<number | null>(null);

  useEffect(() => {
    const node = wrapRef.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) => {
      setWidth(Math.max(280, Math.round(entry.contentRect.width)));
    });
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const top = ticks[ticks.length - 1]?.value || 1;
  const innerWidth = width - MARGIN.left - MARGIN.right;
  const step = data.length > 1 ? innerWidth / (data.length - 1) : 0;
  const x = (i: number) => MARGIN.left + i * step;
  const y = (v: number) => MARGIN.top + PLOT_HEIGHT - (v / top) * PLOT_HEIGHT;
  const height = MARGIN.top + PLOT_HEIGHT + MARGIN.bottom;
  const last = data.length - 1;

  // Narrow screens label every other month so the axis never collides.
  const labelEvery = innerWidth / data.length < 34 ? 2 : 1;

  // End labels ride the line ends unless the two ends are too close to tell
  // apart; then the legend and tooltip carry identity instead of stacked text.
  const endY = SERIES.map((s) => y(data[last]?.[s.key] ?? 0));
  const showEndLabels = data.length > 0 && Math.abs(endY[0] - endY[1]) >= 16;

  const pickFromPointer = (event: PointerEvent<SVGSVGElement>) => {
    const box = event.currentTarget.getBoundingClientRect();
    const px = ((event.clientX - box.left) / box.width) * width;
    const index = step > 0 ? Math.round((px - MARGIN.left) / step) : 0;
    setActive(Math.min(last, Math.max(0, index)));
  };

  const onKeyDown = (event: KeyboardEvent<SVGSVGElement>) => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      const delta = event.key === 'ArrowLeft' ? -1 : 1;
      setActive((current) => Math.min(last, Math.max(0, (current ?? last) + delta)));
    } else if (event.key === 'Escape') {
      setActive(null);
    }
  };

  const activeDatum = active === null ? null : data[active];
  // The readout sits beside the crosshair (flipping left near the right edge)
  // so it never covers the markers of the month being read. 176px = w-44.
  const tooltipLeft =
    active === null ? 0 : x(active) + 12 + 176 > width ? x(active) - 12 - 176 : x(active) + 12;

  return (
    <div className={styles.root}>
      <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-vera-fg-muted">
        {SERIES.map((s) => (
          <span key={s.key} className="inline-flex items-center gap-2">
            <span className={styles.lineKey} style={{ backgroundColor: s.color }} />
            {s.label}
          </span>
        ))}
      </div>

      <div ref={wrapRef} className="relative mt-2 w-full">
        <svg
          width={width}
          height={height}
          viewBox={`0 0 ${width} ${height}`}
          className={`${styles.svg} block max-w-full touch-pan-y outline-none focus-visible:ring-2 focus-visible:ring-vera-focus`}
          role="img"
          aria-label={`Spending and income per month, last ${data.length} months, in ${currency}. Use left and right arrows to read each month.`}
          // biome-ignore lint/a11y/noNoninteractiveTabindex: arrow keys move the crosshair
          tabIndex={0}
          onPointerMove={pickFromPointer}
          onPointerDown={pickFromPointer}
          onPointerLeave={() => setActive(null)}
          onKeyDown={onKeyDown}
          onBlur={() => setActive(null)}
        >
          {ticks.map(({ value: tick, label }) => (
            <g key={tick}>
              <line
                x1={MARGIN.left}
                x2={width - MARGIN.right}
                y1={y(tick)}
                y2={y(tick)}
                stroke={tick === 0 ? 'var(--chart-axis)' : 'var(--chart-grid)'}
                strokeWidth={1}
                shapeRendering="crispEdges"
              />
              <text
                x={MARGIN.left - 8}
                y={y(tick)}
                dy="0.32em"
                textAnchor="end"
                fontSize={11}
                fill="var(--chart-ink-muted)"
              >
                {label}
              </text>
            </g>
          ))}

          {data.map((d, i) =>
            i % labelEvery === last % labelEvery ? (
              <text
                key={d.month}
                x={x(i)}
                y={MARGIN.top + PLOT_HEIGHT + 18}
                textAnchor="middle"
                fontSize={11}
                fill={i === active ? 'var(--chart-ink)' : 'var(--chart-ink-muted)'}
              >
                {d.short}
              </text>
            ) : null,
          )}

          {activeDatum && active !== null ? (
            <line
              x1={x(active)}
              x2={x(active)}
              y1={MARGIN.top}
              y2={MARGIN.top + PLOT_HEIGHT}
              stroke="var(--chart-axis)"
              strokeWidth={1}
              shapeRendering="crispEdges"
            />
          ) : null}

          {SERIES.map((s) => (
            <polyline
              key={s.key}
              points={data.map((d, i) => `${x(i)},${y(d[s.key])}`).join(' ')}
              fill="none"
              stroke={s.color}
              strokeWidth={2}
              strokeLinejoin="round"
              strokeLinecap="round"
            />
          ))}

          {/* End markers (and the hovered month's markers) with a 2px surface ring. */}
          {SERIES.map((s) =>
            [last, ...(active !== null && active !== last ? [active] : [])].map((i) =>
              data[i] ? (
                <circle
                  key={`${s.key}-${i}`}
                  cx={x(i)}
                  cy={y(data[i][s.key])}
                  r={4}
                  fill={s.color}
                  stroke="var(--chart-surface)"
                  strokeWidth={2}
                />
              ) : null,
            ),
          )}

          {showEndLabels
            ? SERIES.map((s, n) => (
                <text
                  key={s.key}
                  x={x(last) + 10}
                  y={endY[n]}
                  dy="0.32em"
                  fontSize={11}
                  fontWeight={600}
                  fill="var(--chart-ink)"
                >
                  {data[last][s.key === 'spending' ? 'spendingShort' : 'incomeShort']}
                </text>
              ))
            : null}
        </svg>

        {activeDatum ? (
          <div
            role="status"
            className="pointer-events-none absolute top-0 z-10 w-44 rounded-vera-md border border-vera-border bg-vera-elevated p-3 text-xs shadow-[var(--vera-shadow-md)]"
            style={{ left: tooltipLeft }}
          >
            <p className="font-medium text-vera-fg-muted">{activeDatum.long}</p>
            {SERIES.map((s) => (
              <p key={s.key} className="mt-1.5 flex items-center justify-between gap-3">
                <span className="inline-flex items-center gap-2 text-vera-fg-muted">
                  <span className={styles.lineKey} style={{ backgroundColor: s.color }} />
                  {s.label}
                </span>
                <span className="text-sm font-bold text-vera-fg">
                  {activeDatum[s.key === 'spending' ? 'spendingText' : 'incomeText']}
                </span>
              </p>
            ))}
          </div>
        ) : null}
      </div>

      <details className="mt-3 text-sm">
        <summary className="cursor-pointer text-vera-fg-muted hover:text-vera-fg">
          Show as table
        </summary>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-left tabular-nums">
            <thead className="text-vera-fg-muted">
              <tr>
                <th className="py-2 pr-3 font-medium">Month</th>
                <th className="py-2 pr-3 text-right font-medium">Spending</th>
                <th className="py-2 pr-3 text-right font-medium">Income</th>
                <th className="py-2 text-right font-medium">Net</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-vera-border">
              {data.map((d) => (
                <tr key={d.month}>
                  <td className="py-2 pr-3">{d.long}</td>
                  <td className="py-2 pr-3 text-right">{d.spendingText}</td>
                  <td className="py-2 pr-3 text-right">{d.incomeText}</td>
                  <td className="py-2 text-right">{d.netText}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </div>
  );
}
