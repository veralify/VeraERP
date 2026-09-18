/**
 * Framer Motion primitives translated from the Veralify design tokens.
 *
 * Source of truth: design-system/veralify/tokens/tokens.json → `motion`
 * (mirrored in design-system/veralify/MASTER.md §3 "Token architecture").
 *
 *   duration.instant  80ms   duration.fast   150ms   duration.base 220ms
 *   duration.slow      360ms  duration.hero   520ms
 *   easing.standard    cubic-bezier(0.2, 0, 0, 1)
 *   easing.emphasized  cubic-bezier(0.2, 0.8, 0.2, 1)
 *   easing.entrance    cubic-bezier(0.16, 1, 0.3, 1)
 *   easing.exit        cubic-bezier(0.7, 0, 0.84, 0)
 *
 * Keep this file in sync by hand if tokens.json's `motion` group changes —
 * it is not code-generated the way tokens.css / Tokens.swift are.
 */
import type { Transition, Variants } from 'framer-motion';

/** Token durations in seconds (Framer Motion's unit), not ms. */
export const veraDuration = {
  instant: 0.08,
  fast: 0.15,
  base: 0.22,
  slow: 0.36,
  hero: 0.52,
} as const;

/** Token easing curves as Framer Motion cubic-bezier tuples. */
export const veraEase = {
  standard: [0.2, 0, 0, 1],
  emphasized: [0.2, 0.8, 0.2, 1],
  entrance: [0.16, 1, 0.3, 1],
  exit: [0.7, 0, 0.84, 0],
} as const;

const entranceTransition: Transition = {
  duration: veraDuration.slow,
  ease: veraEase.entrance,
};

/**
 * Content entrance: rises in while fading up. Use for section headers,
 * cards, and rows appearing after a fetch/interaction settles.
 */
export const fadeUp: Variants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: entranceTransition },
};

/**
 * Emphasis entrance: scales in from slightly-shrunk, for cards, modals,
 * and booking confirmations that should feel like they "arrive".
 */
export const scaleIn: Variants = {
  hidden: { opacity: 0, scale: 0.96 },
  show: {
    opacity: 1,
    scale: 1,
    transition: { duration: veraDuration.base, ease: veraEase.emphasized },
  },
};

/**
 * Parent wrapper for a grid/list of `fadeUp` (or `scaleIn`) children —
 * staggers each child's entrance using the `fast` token as the cadence.
 */
export const staggerContainer: Variants = {
  hidden: {},
  show: {
    transition: {
      staggerChildren: veraDuration.fast,
      delayChildren: veraDuration.instant,
    },
  },
};

/** Quick fade for inline messaging (banners/toasts) — uses `base` + `standard`. */
export const fadeInOut: Variants = {
  hidden: { opacity: 0, y: -8 },
  show: { opacity: 1, y: 0, transition: { duration: veraDuration.base, ease: veraEase.standard } },
  exit: { opacity: 0, y: -8, transition: { duration: veraDuration.fast, ease: veraEase.exit } },
};
