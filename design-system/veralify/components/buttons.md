# Buttons

Referenced screens: `WelcomeScreen`, `PaywallScreen`, `FoodCameraView`, `FoodAnalysisView`, `BookingView`, `/pricing`, `/app/track`, `/coach/sessions`.

## Anatomy
- Container: rounded interactive surface using `radii.pill` or `radii.lg` for icon-only controls.
- Label: action verb, `typography.body-strong`; optional leading/trailing icon from SF Symbols (iOS) or Lucide (web).
- Progress layer: inline spinner and loading label for async actions such as purchase, confirm food, booking.

## Variants
- Primary / `VeraPrimaryButton` / `VeraButton variant="primary"`: `color.primary`, `color.on-primary`, `elevation.shadow.glow-primary` for key CTAs (`Get Started`, `Take Photo`, `Confirm`).
- Secondary / `VeraSecondaryButton`: `color.surface`, `color.fg`, `color.border` for `Sign In`, `Edit`, `Restore purchases`.
- Destructive / `VeraDestructiveButton`: `color.danger`, `color.fg-inverse` for `leave`, `remove participant`, `end room`.
- Coach / `VeraCoachButton`: `color.coach-accent`, `color.on-secondary` for `book` and coach marketplace CTAs.
- Ghost / `VeraGhostButton`: transparent, `color.fg-muted`; for low-emphasis navigation and inline retries.
- Floating create / `VeraCreateButton`: center plus button in the iOS tab bar and web mobile bottom bar, `color.secondary` with `radii.pill`.

## States
- Default: visible 44px/44pt minimum hit target, `spacing.4` horizontal padding.
- Hover (web): raise with `motion.duration.fast`, `motion.easing.standard`, switch to `color.primary-strong` or `color.elevated`.
- Pressed: scale to 0.98 without layout shift; haptic `.light` on iOS for primary/create.
- Focus: 3px outline using `color.focus`; never remove keyboard focus.
- Disabled: 45% opacity, no glow, pointer disabled; include disabled reason for purchase/permission gates.
- Loading: preserve button width, replace icon with spinner, announce `aria-busy` / SwiftUI `.accessibilityValue("Loading")`.
- Error: keep action available, show adjacent inline error using `color.danger`.

## Token usage
Use `color.primary`, `color.primary-strong`, `color.on-primary`, `color.secondary`, `color.coach-accent`, `color.danger`, `color.surface`, `color.border`, `typography.body-strong`, `spacing.3-6`, `radii.pill`, `elevation.shadow.sm`, `motion.duration.fast/base`.

## Accessibility
Labels must be explicit (`Confirm food analysis`, not `Confirm` when context is unclear). Icon-only controls require `accessibilityLabel` / `aria-label`. Hit targets are at least `safeArea.ios.minimumHitTarget` / 44px. Support Dynamic Type by allowing label wrapping to two lines in wizard/paywall contexts.
