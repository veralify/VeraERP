import { StaggerItem } from '@components/generic/Motion';
import { ArrowDownRight, ArrowUpRight, type LucideIcon, Minus } from 'lucide-react';

/**
 * A headline figure with its change against a named period. The delta's
 * colour means good/bad, not up/down: more spending is bad, more income is
 * good, so the caller says which way is good. The arrow and words carry the
 * same meaning for anyone who can't see the colour.
 */
export function StatTile({
  label,
  value,
  icon: Icon,
  delta,
  upIsGood = true,
  comparedTo,
  footnote,
}: {
  label: string;
  value: string;
  icon: LucideIcon;
  /**
   * Signed percentage change, or null when there is nothing to compare with.
   * Omit it (with `comparedTo`) for a figure that has no comparison.
   */
  delta?: number | null;
  upIsGood?: boolean;
  comparedTo?: string;
  footnote?: string;
}) {
  const rounded = delta === null || delta === undefined ? null : Math.round(delta);
  const flat = rounded === 0;
  const good = rounded !== null && !flat && rounded > 0 === upIsGood;
  const DeltaIcon = rounded === null || flat ? Minus : rounded > 0 ? ArrowUpRight : ArrowDownRight;
  const tone =
    rounded === null || flat
      ? 'text-vera-fg-muted'
      : good
        ? 'text-vera-success'
        : 'text-vera-danger';

  return (
    <StaggerItem
      as="article"
      className="rounded-vera-xl border border-vera-border bg-vera-surface p-5 shadow-[var(--vera-shadow-sm)]"
    >
      <div className="flex items-center gap-2 text-sm text-vera-fg-muted">
        <Icon className="h-4 w-4 text-vera-primary" strokeWidth={1.75} aria-hidden="true" />
        {label}
      </div>
      <p className="mt-3 text-3xl font-black tracking-tight">{value}</p>
      {comparedTo ? (
        <p className={`mt-2 flex items-center gap-1 text-xs font-medium ${tone}`}>
          <DeltaIcon className="h-3.5 w-3.5" strokeWidth={2} aria-hidden="true" />
          {rounded === null
            ? `No figure for ${comparedTo}`
            : flat
              ? `Same as ${comparedTo}`
              : `${Math.abs(rounded)}% ${rounded > 0 ? 'more' : 'less'} than ${comparedTo}`}
        </p>
      ) : null}
      {footnote ? <p className="mt-1 text-xs text-vera-fg-subtle">{footnote}</p> : null}
    </StaggerItem>
  );
}
