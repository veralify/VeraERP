# Charts

Referenced screens: `HomeView`, `PlanRevealScreen`, `FoodAnalysisView`, `ProgressDashboardView`, `GoalDetailView`, `MilestonesView`, `ClientDetailView`, `/app/progress`, `/coach/progress`, `/admin/analytics`.

## Anatomy
- Title and time range selector.
- Plot/ring/bar region.
- Legend using text + swatch.
- Summary insight and optional CTA.

## Variants
- `VeraWeightTrendChart`: line chart with goal band, check-in markers, measurement annotations.
- `VeraMacroBars`: stacked or grouped bars for protein/carbs/fat; used in Food Log and Coach Client Nutrition.
- `VeraCalorieRing`: calorie remaining/consumed ring; supports exceeded state.
- `VeraProgressRing`: reusable goal progress for Home and Goal Detail.
- `VeraMiniSparkline`: compact card trend.

## States
Default: axes/grid use `color.border`, data uses domain colors. Hover/focus (web): tooltip and focused point. Pressed (iOS): scrubber with haptic. Loading: chart skeleton matching dimensions. Empty: message such as `Log your first weight entry` with CTA. Error: retry and stale-data timestamp. Offline: show cached data with offline banner from `states.md`.

## Token usage
Use `color.nutrition.calories/protein/carbs/fat/water`, `color.progress.on-track/behind/exceeded`, `color.primary`, `color.fg-muted`, `color.border`, `typography.caption/mono-numeric`, `spacing.3-6`, `radii.lg`, `motion.duration.slow`.

## Accessibility
Charts must provide summaries (`Calories 1,820 of 2,100, on track`) and data tables or VoiceOver chart descriptors. Do not rely on color alone: add labels, patterns, or icons. Minimum text contrast AA; tooltip content stays in DOM for screen readers when focused.
