# Veralify Design System Master

**Project:** Veralify — fitness & social platform  
**Positioning:** Track. Connect. Transform.  
**Mode:** Dark-first, light-complete, premium fitness utility  
**Source of truth:** `design-system/veralify/tokens/tokens.json`

## 1. Brand essence

Veralify keeps the original premium/minimal Veralify language: high contrast, restrained surfaces, generous negative space, soft depth, and a calm luxury feel. The pivot evolves that language from travel concierge into a gym/evening fitness product: more actionable, data-rich, and social, while staying uncluttered.

The product should feel like a trusted transformation cockpit:
- **Track:** precise nutrition, progress, goals, and trends.
- **Connect:** groups, posts, messaging, live rooms, and shared films.
- **Transform:** AI guidance, streaks, coaching, and plan reveal moments.

## 2. Visual direction

- **Primary appearance:** dark obsidian canvas for gyms/evenings, with glass surfaces and crisp data colors.
- **Core brand color:** electric blue `color.primary` for tracking, AI, progress, and main CTAs.
- **Legacy warmth preserved:** the current iOS orange accent is retained as `color.secondary` and `color.coach-accent`, used for creation energy and coaching marketplace moments.
- **Premium minimalism:** no noisy gamification, no emoji icons, no low-contrast neon-on-black. Use Lucide on web and SF Symbols on iOS.
- **Data semantics:** nutrition and progress use named tokens rather than arbitrary chart colors.

## 3. Token architecture

`tokens/tokens.json` is canonical. `scripts/generate-tokens.mjs` deterministically generates:

- `tokens/tokens.css` — CSS custom properties and Tailwind CSS v4 `@theme` variables.
- `tokens/Tokens.swift` — SwiftUI constants under `enum VeraTokens`.

Token groups:
- `color.ramp`: raw ramps for slate, blue, ember, green, yellow, red, violet, cyan.
- `color.semantic`: adaptive dark/light roles (`bg`, `surface`, `elevated`, `primary`, `secondary`, `accent`, `success`, `warning`, `danger`, `info`, borders, focus, glass, coach accent).
- `color.nutrition`: calories, protein, carbs, fat, water.
- `color.progress`: on-track, behind, exceeded.
- `color.live`: live-red, speaking-glow.
- `typography`: display, h1-h3, body, caption, mono-numeric.
- `spacing`, `radii`, `borders`, `elevation`, `motion`, `zIndex`, `breakpoints`, `safeArea`.

The generator performs WCAG AA contrast checks for core foreground/background pairs and warns if any fall below 4.5:1.

## 4. Contribution rules

1. Edit **only** `tokens/tokens.json` for token value changes.
2. Run `node design-system/veralify/scripts/generate-tokens.mjs` after token changes.
3. Do not hand-edit `tokens/tokens.css` or `tokens/Tokens.swift`; both files have a generated header.
4. Component specs must reference token names, not raw color values.
5. Dark mode is the design baseline; every addition must include light-mode behavior.
6. Maintain 44px/44pt minimum touch targets and visible focus states.
7. Respect `prefers-reduced-motion` on web and Reduce Motion on iOS.
8. Keep component naming paired: `VeraX` for SwiftUI and `VeraX`/`VeraXProps` for React where possible.

## 5. Component contract index

- `components/buttons.md` — primary, secondary, destructive, coach, ghost, floating create.
- `components/cards.md` — metric cards, `AIInsightCard`, food cards, macro/progress rings, streak, paywall feature cards.
- `components/navigation.md` — iOS floating tab bar with center create button, web sidebar/topbar/mobile nav.
- `components/forms.md` — inputs, numeric fields, steppers, segmented controls, onboarding/goal wizard.
- `components/charts.md` — weight trend, macro bars, calorie/progress rings, chart states.
- `components/feed.md` — post cards, comments, group cards, moderation states.
- `components/live-room.md` — live badges, room cards, speaker grid, request-to-speak, host moderation.
- `components/coach.md` — coach cards, session cards, booking calendar, review stars.
- `components/ai.md` — chat bubbles, streaming, confidence badge, food-scan overlay.
- `components/states.md` — loading, empty, error, offline, paywall lock.

## 6. Web adoption

Import `design-system/veralify/tokens/tokens.css` from the web global stylesheet or copy it into the web CSS bundle before app-level styles. Tailwind v4 can use generated utilities such as `bg-vera-bg`, `text-vera-fg`, `border-vera-border`, `rounded-vera-xl`, and spacing variables like `p-vera-4` where supported by the configured Tailwind compiler. Existing aliases (`--page-bg`, `--text-main`, `--brand-primary`, `--glass-bg`) are included only as migration bridges.

## 7. iOS adoption

Copy or reference `tokens/Tokens.swift` inside the iOS target, then use `VeraTokens.Colors`, `VeraTokens.Type`, `VeraTokens.Spacing`, `VeraTokens.Radii`, and `VeraTokens.SafeArea`. Replace legacy `AppTheme` values gradually with token-backed aliases to avoid breaking existing views.

## 8. Conflicts resolved

- Previous `MASTER.md` used navy/blue on a light-first luxury site. The new system keeps premium minimalism but changes the baseline to dark-first fitness.
- Existing iOS `AppTheme.accent` is orange. Rather than discard it, orange becomes `color.secondary` and `color.coach-accent`; blue becomes the shared primary because web already leans blue and tracking/AI need a crisp system accent.
- Existing web globals include Apple-style day/night aliases. Generated CSS includes transitional aliases so web can migrate without a one-shot rewrite.
