'use client';

import { AlertTriangle } from 'lucide-react';

/**
 * Shared route error-boundary UI — see design-system/veralify/components/states.md
 * `VeraErrorState`: "plain-language problem, recovery action." Used by
 * `error.tsx` files, which pass Next's `reset()` as `onRetry`.
 */
export function RouteErrorState({
  title = 'Something went wrong',
  body = "We couldn't load this page. Try again, and reach out if it keeps happening.",
  onRetry,
}: {
  title?: string;
  body?: string;
  onRetry: () => void;
}) {
  return (
    <div
      role="alert"
      className="mx-auto max-w-lg rounded-vera-2xl border border-vera-border bg-vera-surface p-8 text-center shadow-[var(--vera-shadow-sm)]"
    >
      <div
        className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-vera-danger/10 text-vera-danger"
        aria-hidden="true"
      >
        <AlertTriangle className="h-6 w-6" strokeWidth={1.75} />
      </div>
      <h2 className="mt-5 text-2xl font-bold tracking-tight">{title}</h2>
      <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-vera-fg-muted">{body}</p>
      <button type="button" onClick={onRetry} className="btn-apple mt-6">
        Try again
      </button>
    </div>
  );
}
