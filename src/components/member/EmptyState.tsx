import { EmptyState as GenericEmptyState } from '@components/generic/EmptyState';
import { Inbox } from 'lucide-react';
import type { ReactNode } from 'react';

/**
 * Thin, backward-compatible wrapper over `@components/generic/EmptyState`.
 * Kept at this path/signature because it's imported across the member
 * dashboard (goals, progress, groups, track, billing, ...) — callers that
 * only pass title/body/ctaHref/ctaLabel keep working unchanged. New call
 * sites (coach discovery/portal) pass a rendered `icon` element for a
 * topic-appropriate glyph instead of the old literal "•" placeholder.
 */
export function EmptyState({
  title,
  body,
  ctaHref,
  ctaLabel,
  icon = <Inbox className="h-6 w-6" strokeWidth={1.75} />,
}: {
  title: string;
  body: string;
  ctaHref?: string;
  ctaLabel?: string;
  icon?: ReactNode;
}) {
  return (
    <GenericEmptyState
      icon={icon}
      title={title}
      body={body}
      ctaHref={ctaHref}
      ctaLabel={ctaLabel}
    />
  );
}
