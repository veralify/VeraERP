'use client';

import { motion, useReducedMotion } from 'framer-motion';
import type { ReactNode } from 'react';

/**
 * Runs once per route segment change (Next.js re-mounts `template.tsx` on
 * every navigation, unlike `layout.tsx`) — gives every page a quick, quiet
 * entrance instead of an abrupt content swap. Kept short and simple on
 * purpose: this is a transition, not a showpiece.
 */
export default function Template({ children }: { children: ReactNode }) {
  const reduceMotion = useReducedMotion();

  if (reduceMotion) return children;

  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
    >
      {children}
    </motion.div>
  );
}
