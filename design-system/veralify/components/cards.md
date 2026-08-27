# Cards

Referenced screens: `HomeView`, `AIInsightCard`, `FoodLogView`, `FoodAnalysisView`, `ProgressDashboardView`, `MilestonesView`, `SubscriptionView`, `/app`, `/app/nutrition`, `/coach/clients/[id]`.

## Anatomy
- Surface: `color.surface` or glass `color.glass`; border `color.border`.
- Header: title, optional status chip, optional overflow action.
- Content: metric, image, chart, or body copy.
- Footer: CTA, timestamp, confidence/provenance, permissions.

## Variants
- `VeraMetricCard`: calories, protein, goal progress, measurements; uses `typography.mono-numeric` for values.
- `AIInsightCard`: insight text plus `Ask AI` CTA; uses `color.accent` and confidence/provenance slot.
- `VeraFoodCard`: meal row with photo thumbnail, calories, macros, source label for `FoodLogView` and `FoodAnalysisView`.
- `VeraMacroRingCard` / `VeraProgressRingCard`: circular progress with domain colors `color.nutrition.*` and `color.progress.*`.
- `VeraStreakCard`: streak count, recovery state, next recommended action.
- `VeraPaywallFeatureCard`: locked feature card using `states.md` paywall lock pattern.

## States
Default: `elevation.shadow.sm`, `radii.xl`, `spacing.5`. Hover: `elevation.shadow.md`, border `color.border-strong`; no content shift. Pressed: subtle scale only on tap/click cards. Disabled/locked: overlay using `color.overlay` and lock affordance. Loading: skeleton blocks sized to final content. Error: inline retry region with `color.danger`. Empty: compact message and CTA.

## Token usage
Use `color.surface`, `color.elevated`, `color.glass`, `color.glass-border`, `color.fg`, `color.fg-muted`, `color.nutrition.calories/protein/carbs/fat/water`, `color.progress.on-track/behind/exceeded`, `radii.lg/xl`, `spacing.4-6`, `elevation.shadow.sm/md`, `motion.duration.base`.

## Accessibility
Cards that navigate are buttons/links with a single accessible name. Metric cards expose value and goal (`Protein 112 of 130 grams`). Rings must include textual percentage. Dynamic Type stacks footer actions below content before truncating.
