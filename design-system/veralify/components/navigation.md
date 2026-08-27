# Navigation

Referenced screens: all iOS tabs (`HomeView`, `TrackView`, `ConnectView`, `LiveDiscoveryView`, `ProfileView`) plus `/app/*`, `/coach/*`, `/admin/*`, public website routes.

## Anatomy
- iOS floating tab bar: glass capsule, five destinations, centered raised `+` create button for §48 creation surface.
- Web app shell: sidebar on `lg+`, topbar on tablet, mobile bottom bar with center create action.
- Public website: top nav with brand, route links, pricing CTA, theme language controls.

## Variants
- `VeraFloatingTabBar` / `VeraMobileNav`: Home, Track, Create, Connect, Profile; Live is surfaced inside Connect and as prominent Home card.
- `VeraWebSidebar`: member app links `/app`, `/app/track`, `/app/nutrition`, `/app/progress`, `/app/groups`, `/app/live`, `/app/messages`, `/app/ai`, `/app/profile`, `/app/settings`, `/app/billing`.
- `VeraCoachSidebar`: `/coach`, clients, nutrition, progress, sessions, calendar, messages, groups, profile, settings.
- `VeraAdminSidebar`: admin users, groups, reports, coaches, subscriptions, ai, analytics.

## States
Default active item uses `color.primary`; inactive uses `color.fg-muted`. Hover uses `color.surface-muted`. Pressed scales icon 0.96. Disabled hides only when inaccessible; permission-gated items show paywall/permission explanation. Loading shows route-level skeleton below persistent nav. Error state keeps nav interactive.

## Token usage
Use `color.glass`, `color.glass-border`, `color.primary`, `color.secondary` for create, `color.fg`, `color.fg-muted`, `radii.pill`, `spacing.2-5`, `safeArea.ios.bottomNavClearance`, `zIndex.nav`, `elevation.shadow.lg`.

## Accessibility
Current route must expose selected state (`aria-current="page"`, SwiftUI `.accessibilityAddTraits(.isSelected)`). Center create button label: `Create food photo, progress photo, post, video, check-in, live room, or shared film`. Maintain 44px/44pt targets and safe-area inset padding.
