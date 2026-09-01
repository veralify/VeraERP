import type { ReactNode } from 'react';

export function PageHeader({
  eyebrow,
  title,
  body,
  action,
}: {
  eyebrow: string;
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <section className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-vera-primary">
          {eyebrow}
        </p>
        <h1 className="mt-2 text-3xl font-black tracking-tight sm:text-5xl">{title}</h1>
        {body ? <p className="mt-3 max-w-2xl text-vera-fg-muted">{body}</p> : null}
      </div>
      {action}
    </section>
  );
}

export function Card({
  children,
  className = '',
  id,
}: {
  children: ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <section
      id={id}
      className={`rounded-vera-2xl border border-vera-border bg-vera-surface p-6 shadow-[var(--vera-shadow-sm)] ${className}`}
    >
      {children}
    </section>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-2 text-sm font-medium text-vera-fg">
      <span>{label}</span>
      {children}
    </div>
  );
}

export const inputClass =
  'min-h-11 rounded-vera-md border border-vera-border bg-vera-bg-subtle px-3 py-2 text-sm text-vera-fg outline-none focus:border-vera-focus';

export function SubmitButton({ children }: { children: ReactNode }) {
  return (
    <button type="submit" className="btn-apple min-h-11">
      {children}
    </button>
  );
}

export function ErrorMessage({ message }: { message?: string }) {
  if (!message) return null;
  return (
    <p
      role="alert"
      className="rounded-vera-md border border-vera-danger/40 bg-vera-danger/10 p-3 text-sm text-vera-danger"
    >
      {message}
    </p>
  );
}

export function Pager({
  page,
  hasNext,
  basePath,
  query = {},
}: {
  page: number;
  hasNext: boolean;
  basePath: string;
  query?: Record<string, string | undefined>;
}) {
  const href = (nextPage: number) => {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(query)) if (value) params.set(key, value);
    if (nextPage > 1) params.set('page', String(nextPage));
    const suffix = params.toString();
    return `${basePath}${suffix ? `?${suffix}` : ''}`;
  };
  return (
    <nav className="mt-6 flex items-center justify-between text-sm" aria-label="Pagination">
      {page > 1 ? (
        <a className="btn-apple-secondary" href={href(page - 1)}>
          Previous
        </a>
      ) : (
        <span />
      )}
      <span className="text-vera-fg-muted">Page {page}</span>
      {hasNext ? (
        <a className="btn-apple-secondary" href={href(page + 1)}>
          Next
        </a>
      ) : (
        <span />
      )}
    </nav>
  );
}

export function MacroBars({
  calories,
  protein,
  carbs,
  fat,
  targets,
}: {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  targets: { calories?: number; protein_g?: number; carbs_g?: number; fat_g?: number };
}) {
  const rows = [
    ['Calories', calories, targets.calories, 'kcal', 'bg-vera-calories'],
    ['Protein', protein, targets.protein_g, 'g', 'bg-vera-protein'],
    ['Carbs', carbs, targets.carbs_g, 'g', 'bg-vera-carbs'],
    ['Fat', fat, targets.fat_g, 'g', 'bg-vera-fat'],
  ] as const;
  return (
    <div
      className="grid gap-4"
      role="img"
      aria-label={`Calories ${calories} of ${targets.calories ?? 0}; protein ${protein}g; carbs ${carbs}g; fat ${fat}g`}
    >
      {rows.map(([label, value, target, unit, color]) => {
        const pct = target ? Math.min(100, Math.round((value / target) * 100)) : 0;
        return (
          <div key={label}>
            <div className="mb-1 flex justify-between text-sm">
              <span>{label}</span>
              <span className="text-vera-fg-muted">
                {value}
                {unit} {target ? `/ ${target}${unit}` : ''}
              </span>
            </div>
            <div className="h-3 overflow-hidden rounded-full bg-vera-surface-muted">
              <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
            </div>
          </div>
        );
      })}
    </div>
  );
}
