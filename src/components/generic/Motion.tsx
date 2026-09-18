'use client';

import { fadeUp, staggerContainer } from '@lib/motion/variants';
import { motion, useReducedMotion, type Variants } from 'framer-motion';
import type { ElementType, ReactNode } from 'react';

/**
 * Small, composable Framer Motion islands for otherwise-server pages.
 * Drop `<Reveal>` around a single section, or wrap a grid/list in
 * `<StaggerGroup>` with each item as a `<StaggerItem>` — entrance timing
 * comes from `src/lib/motion/variants.ts` (itself sourced from
 * design-system/veralify/MASTER.md's `motion` tokens).
 *
 * Every primitive here calls `useReducedMotion()` and falls back to a
 * plain, unanimated element for users who prefer reduced motion.
 */

export function Reveal({
  children,
  className,
  variants = fadeUp,
  as = 'div',
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  variants?: Variants;
  as?: ElementType;
  delay?: number;
}) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as 'div'];

  if (reduceMotion) {
    const Tag = as;
    return <Tag className={className}>{children}</Tag>;
  }

  return (
    <MotionTag
      className={className}
      initial="hidden"
      animate="show"
      variants={variants}
      transition={{ delay }}
    >
      {children}
    </MotionTag>
  );
}

export function StaggerGroup({
  children,
  className,
  as = 'div',
}: {
  children: ReactNode;
  className?: string;
  as?: ElementType;
}) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as 'div'];

  if (reduceMotion) {
    const Tag = as;
    return <Tag className={className}>{children}</Tag>;
  }

  return (
    <MotionTag className={className} initial="hidden" animate="show" variants={staggerContainer}>
      {children}
    </MotionTag>
  );
}

export function StaggerItem({
  children,
  className,
  variants = fadeUp,
  as = 'div',
}: {
  children: ReactNode;
  className?: string;
  variants?: Variants;
  as?: ElementType;
}) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as 'div'];

  if (reduceMotion) {
    const Tag = as;
    return <Tag className={className}>{children}</Tag>;
  }

  return (
    <MotionTag className={className} variants={variants}>
      {children}
    </MotionTag>
  );
}
