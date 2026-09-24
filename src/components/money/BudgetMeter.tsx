import type { BudgetState } from '@lib/money/spending';
import { AlertTriangle, CheckCircle2, XCircle } from 'lucide-react';

const STATE = {
  ok: {
    label: 'On track',
    icon: CheckCircle2,
    fill: 'bg-vera-primary',
    track: 'bg-vera-primary/15',
    ink: 'text-vera-fg-muted',
  },
  near: {
    label: 'Near limit',
    icon: AlertTriangle,
    fill: 'bg-vera-warning',
    track: 'bg-vera-warning/20',
    ink: 'text-vera-warning',
  },
  over: {
    label: 'Over budget',
    icon: XCircle,
    fill: 'bg-vera-danger',
    track: 'bg-vera-danger/20',
    ink: 'text-vera-danger',
  },
} as const;

/**
 * One budget as a meter: the fill carries severity (accent → warning →
 * danger) over a lighter track of the same hue, and the state is always
 * spelled out with an icon and a word, never colour alone.
 */
export function BudgetMeter({
  label,
  state,
  ratio,
  spentText,
  limitText,
  remainingText,
}: {
  label: string;
  state: BudgetState;
  ratio: number;
  spentText: string;
  limitText: string;
  remainingText: string;
}) {
  const style = STATE[state];
  const Icon = style.icon;
  const pct = Math.round(ratio * 100);
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3 text-sm">
        <span className="truncate font-semibold">{label}</span>
        <span className="flex-none text-vera-fg-muted tabular-nums">
          {spentText} / {limitText}
        </span>
      </div>
      {/* Decorative: the line below states the same percentage and state in words. */}
      <div className={`mt-2 h-2 overflow-hidden rounded-full ${style.track}`} aria-hidden="true">
        <div
          className={`h-full rounded-full ${style.fill}`}
          style={{ width: `${Math.min(100, Math.max(ratio > 0 ? 2 : 0, pct))}%` }}
        />
      </div>
      <p className={`mt-1.5 flex items-center gap-1.5 text-xs ${style.ink}`}>
        <Icon className="h-3.5 w-3.5 flex-none" strokeWidth={2} aria-hidden="true" />
        <span>
          {style.label} · {pct}% used · {remainingText}
        </span>
      </p>
    </div>
  );
}
