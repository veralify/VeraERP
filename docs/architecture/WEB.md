# Web Architecture

## Route map

Public routes: `/`, `/features`, `/ai`, `/tracking`, `/communities`, `/live`, `/coaches`, `/pricing`, `/about`, `/help`, `/privacy`, `/terms`, `/welcome`.

Member routes are under `/dashboard`: dashboard, track, nutrition, progress, goals, groups, live, messages, AI, profile, and billing.

## Auth guard

`src/middleware.ts` refreshes the Supabase SSR session and forwards `x-pathname` so the root layout can hide public chrome for member pages. `src/app/dashboard/layout.tsx` performs the server-side guard with `createSupabaseServerClient().auth.getUser()` and redirects unauthenticated users to `/?auth=required`.

## Design tokens

`src/app/globals.css` imports `design-system/veralify/tokens/tokens.css` before Tailwind so `bg-vera-*`, `text-vera-*`, spacing, radii, and CSS custom properties resolve from the design system.

## Stubbed for later phases

Member pages intentionally render honest empty states until backend APIs provide meals, goals, progress, groups, live rooms, messages, AI insights, and profile editing. Billing uses existing Stripe checkout and portal routes; real Stripe products/prices must be configured with `STRIPE_PRICE_VERALIFY_PRO_WEEKLY`, `STRIPE_PRICE_VERALIFY_PRO_MONTHLY`, and `STRIPE_PRICE_VERALIFY_PRO_ANNUAL`.
