# Forms

Referenced screens: `GoalSelectionScreen`, `ProfileSetupScreen`, `TargetSetupScreen`, `PaywallScreen`, `BarcodeScannerView`, `MealEditorView`, `WeightEntryView`, `EditProfileView`, `AISettingsView`, `AccountSecurityView`, `/app/settings`, `/coach/profile`.

## Anatomy
- Field container: label, control, helper/error text, optional unit or icon.
- Wizard step: progress indicator, question title, selectable answers, continue/back actions.
- Inputs use `color.surface`, `color.border`, focus ring `color.focus`.

## Variants
- `VeraTextField`: text, email, password, notes.
- `VeraNumericField`: height, weight, portion, macro target; uses `typography.mono-numeric`.
- `VeraStepper`: servings, duration, target increments.
- `VeraSegmentedControl`: Food/Progress/Goals/Trends tabs and unit preferences.
- `VeraGoalChoiceCard`: lose fat, build muscle, gain weight, improve fitness, improve nutrition, build consistency.
- `VeraReferralCodeField`: Paywall referral code entry.

## States
Default: clear label and helper. Hover: border `color.border-strong`. Focus: `color.focus` outline. Pressed for segmented/choices: selected fill `color.primary`, selected text `color.on-primary`. Disabled: muted surface. Loading: preserve control height with shimmer. Error: border/text `color.danger`, actionable copy. Valid/success: confirmation using `color.success`.

## Token usage
Use `color.surface`, `color.elevated`, `color.border`, `color.focus`, `color.danger`, `color.success`, `color.primary`, `color.on-primary`, `typography.body/caption/mono-numeric`, `spacing.2-6`, `radii.md/lg/pill`, `motion.duration.fast`.

## Accessibility
Every field has a programmatic label and error relation (`aria-describedby`, SwiftUI accessibility hint). Numeric fields announce units. Dynamic Type may turn segmented controls into stacked choice cards. Keyboard order follows visual order; forms avoid trapping focus in paywall or account security flows.
