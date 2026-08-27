# Global States

Referenced screens: all onboarding, home, tracking, progress, connect, live, messaging, coaching, profile, web member/coach/admin routes.

## Anatomy
- Loading skeleton: shape matching final component.
- Empty state: concise title, cause, one primary CTA, optional illustration using design tokens.
- Error state: plain-language problem, recovery action, support/report path when needed.
- Offline banner: sticky compact notice with cached-data timestamp.
- Paywall lock: lock icon, feature value, trial/plan CTA.

## Variants
- `VeraSkeleton`: text, card, chart, avatar, media, feed row.
- `VeraEmptyState`: `No meals logged yet`, `No live rooms now`, `No upcoming sessions`.
- `VeraErrorState`: network/API/payment/permission errors.
- `VeraOfflineBanner`: app-wide cached mode.
- `VeraPaywallLock`: hard paywall and feature-level lock for no-free-tier areas.

## States
Default: skeleton shimmer uses `color.surface-muted`; reduced motion swaps shimmer for static blocks. Hover/pressed applies only to retry/CTA buttons. Disabled prevents repeated retry while loading. Loading variants reserve final layout height. Error variants never blame the user; provide retry. Offline state remains dismissible only after connectivity returns. Paywall state preserves context and routes to `PaywallScreen`, `SubscriptionView`, `/pricing`, or `/app/billing`.

## Token usage
Use `color.surface`, `color.surface-muted`, `color.border`, `color.fg`, `color.fg-muted`, `color.warning`, `color.danger`, `color.info`, `color.primary`, `color.on-primary`, `spacing.4-8`, `radii.lg/xl`, `zIndex.toast`, `motion.duration.slow`.

## Accessibility
Loading regions expose `aria-busy` / SwiftUI progress semantics. Empty/error titles are headings. Offline banner uses `role="status"` / polite announcement. Paywall lock names the locked feature and available action. Dynamic Type stacks art above copy and keeps CTAs visible.
