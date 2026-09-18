'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { Camera, Flame, Radio, TrendingUp } from 'lucide-react';

/**
 * The right-hand visual cluster on the homepage hero: three glass cards
 * standing in for the three brand pillars (Track / Connect / Transform),
 * each gently floating. No product screenshots exist pre-launch, so this
 * stays abstract/data-driven rather than a fabricated app-screen mockup.
 */
export function HeroVisual() {
  const reduceMotion = useReducedMotion();

  const float = (delay: number) =>
    reduceMotion
      ? undefined
      : {
          y: [0, -10, 0],
          transition: {
            duration: 5,
            delay,
            repeat: Number.POSITIVE_INFINITY,
            ease: 'easeInOut' as const,
          },
        };

  return (
    <div className="relative mx-auto aspect-square w-full max-w-md">
      <div className="absolute inset-0 -z-10 rounded-full bg-[radial-gradient(circle,color-mix(in_srgb,var(--vera-color-primary)_28%,transparent),transparent_70%)] blur-2xl" />

      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.1 }}
        className="absolute left-0 top-4 w-56 rounded-vera-xl border border-vera-glass-border bg-vera-glass p-4 shadow-[var(--vera-shadow-lg)] backdrop-blur-xl"
      >
        <motion.div animate={float(0)}>
          <div className="flex items-center gap-2 text-vera-primary">
            <Camera className="h-4 w-4" strokeWidth={2} />
            <p className="text-xs font-semibold uppercase tracking-wide">Track</p>
          </div>
          <p className="mt-3 text-sm font-semibold">Photo → macros</p>
          <div className="mt-3 grid grid-cols-2 gap-1.5 text-[11px]">
            <span className="rounded-vera-sm bg-[color-mix(in_srgb,var(--vera-color-nutrition-calories)_18%,transparent)] px-2 py-1 text-vera-fg-muted">
              612 kcal
            </span>
            <span className="rounded-vera-sm bg-[color-mix(in_srgb,var(--vera-color-nutrition-protein)_18%,transparent)] px-2 py-1 text-vera-fg-muted">
              41g protein
            </span>
          </div>
        </motion.div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.25 }}
        className="absolute right-0 top-32 w-48 rounded-vera-xl border border-vera-glass-border bg-vera-glass p-4 shadow-[var(--vera-shadow-lg)] backdrop-blur-xl"
      >
        <motion.div animate={float(0.6)}>
          <div className="flex items-center gap-2 text-vera-coach-accent">
            <Radio className="h-4 w-4" strokeWidth={2} />
            <p className="text-xs font-semibold uppercase tracking-wide">Connect</p>
          </div>
          <div className="mt-3 flex items-center gap-2">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-vera-live-live-red opacity-60" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-vera-live-live-red" />
            </span>
            <p className="text-sm font-semibold">Morning Run Club</p>
          </div>
          <p className="mt-2 text-[11px] text-vera-fg-muted">12 live now</p>
        </motion.div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.4 }}
        className="absolute bottom-2 left-8 w-52 rounded-vera-xl border border-vera-glass-border bg-vera-glass p-4 shadow-[var(--vera-shadow-lg)] backdrop-blur-xl"
      >
        <motion.div animate={float(1.1)}>
          <div className="flex items-center gap-2 text-vera-secondary">
            <Flame className="h-4 w-4" strokeWidth={2} />
            <p className="text-xs font-semibold uppercase tracking-wide">Transform</p>
          </div>
          <p className="mt-3 flex items-baseline gap-1">
            <span className="text-2xl font-black tracking-tight">18</span>
            <span className="text-xs text-vera-fg-muted">day streak</span>
          </p>
          <div className="mt-2 flex items-center gap-1 text-[11px] text-vera-success">
            <TrendingUp className="h-3 w-3" strokeWidth={2.5} />
            On track for goal
          </div>
        </motion.div>
      </motion.div>
    </div>
  );
}
