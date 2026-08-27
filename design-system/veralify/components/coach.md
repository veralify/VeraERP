# Coach

Referenced screens: `CoachDiscoveryView`, `CoachProfileView`, `BookingView`, `CoachSessionView`, `CoachDashboardView`, `ClientDetailView`, `/coach`, `/coach/calendar`, `/coach/sessions`.

## Anatomy
- Coach card: avatar/video, name, specialties, price, rating, next availability, book CTA.
- Session card: client/coach, time, status, video/chat entry, payment/entitlement state.
- Booking calendar: month/week picker, available slots, duration, confirmation.
- Review stars: rating value, count, review excerpts.

## Variants
- `VeraCoachCard`: discovery grid/list.
- `VeraCoachProfileHeader`: profile and book action.
- `VeraSessionCard`: upcoming, completed, cancelled.
- `VeraBookingCalendar`: date and time selection.
- `VeraReviewStars`: read-only and input modes.

## States
Default: `color.coach-accent` highlights marketplace actions. Hover: card/action lift. Pressed: selection haptic. Disabled: unavailable slot or missing coach entitlement. Loading: schedule skeleton. Error: booking/payment retry. Success: confirmed booking state using `color.success`. Cancelled: `color.warning` or `color.danger` based on refund/action required.

## Token usage
Use `color.coach-accent`, `color.secondary`, `color.on-secondary`, `color.surface`, `color.elevated`, `color.success/warning/danger`, `typography.h3/body/caption/mono-numeric`, `spacing.3-8`, `radii.xl`, `elevation.shadow.md`.

## Accessibility
Ratings expose value and count (`4.8 out of 5, 126 reviews`). Calendar supports keyboard navigation and VoiceOver date availability. Price/duration uses clear text, not icon-only. Permission-controlled `ClientDetailView` tabs show accessible locked state.
