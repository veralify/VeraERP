'use client';

import { fadeUp } from '@lib/motion/variants';
import { motion, useReducedMotion } from 'framer-motion';
import { Inbox } from 'lucide-react';
import type { ReactNode } from 'react';

/**
 * Icon-based empty state — see design-system/veralify/components/states.md
 * `VeraEmptyState`: "concise title, cause, one primary CTA, optional
 * illustration using design tokens." Supersedes the old literal "•"
 * placeholder glyph with a real Lucide icon.
 *
 * `icon` takes an already-rendered element (e.g. `<Lock className="h-6 w-6" />`)
 * rather than a component reference — this is a client component, and a
 * server page can't pass a bare component/function across that boundary,
 * only a rendered element.
 */
export function EmptyState({
  icon = <Inbox className="h-6 w-6" strokeWidth={1.75} />,
  title,
  body,
  ctaHref,
  ctaLabel,
  className = '',
}: {
  icon?: ReactNode;
  title: string;
  body: string;
  ctaHref?: string;
  ctaLabel?: string;
  className?: string;
}) {
  const reduceMotion = useReducedMotion();
  const wrapperClassName = `rounded-vera-2xl border border-vera-border bg-vera-surface p-8 text-center shadow-[var(--vera-shadow-sm)] ${className}`;

  const content = (
    <>
      <div
        className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-vera-surface-muted text-vera-primary"
        aria-hidden="true"
      >
        {icon}
      </div>
      <h2 className="mt-5 text-2xl font-bold tracking-tight">{title}</h2>
      <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-vera-fg-muted">{body}</p>
      {ctaHref && ctaLabel ? (
        <a className="btn-apple mt-6" href={ctaHref}>
          {ctaLabel}
        </a>
      ) : null}
    </>
  );

  if (reduceMotion) {
    return <section className={wrapperClassName}>{content}</section>;
  }

  return (
    <motion.section className={wrapperClassName} initial="hidden" animate="show" variants={fadeUp}>
      {content}
    </motion.section>
  );
}
