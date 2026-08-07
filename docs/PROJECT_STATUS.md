# Veralify — Project Status & Change Log

_Single source of truth for project state and MVP progress. Updated on every meaningful change._

**Last updated:** 2026-08-07 14:42 (local)

## Overall Build Status (Repo-Derived)

**VERALIFY Project Build Status:** **[███████░░░] 68%**

> Based on implemented code and integrations across `src/`, `supabase/`, and `veralify-App/` (not only planning text).

---

## MVP Launch Progress: **~68%**

| Area | Progress | One-line state |
|------|:---:|----|
| 🌐 Website (Next.js) | **75%** | Polished Apple-styled landing + full auth + waitlist live; needs payments UI & authed dashboard depth |
| 📱 iOS App (SwiftUI) | **70%** | All core flows built (AI concierge, Explore, Purchase, MyESIMs, Profile); needs passkeys, push, Stripe, realtime |
| ⚙️ Backend (Supabase) | **60%** | 17 migrations + 7 edge functions + AI gateway w/ credits; needs Stripe webhooks, APNs, realtime |

> % are engineering-completeness estimates against the MVP scope in `docs/BACKEND_PLAN.md`. Waitlist/"coming soon" web launch is effectively ready; full app+payments MVP is the ~68% figure.

---

## 🌐 Website (Next.js 15 · React 19 · Vercel)

**Done**
- Apple-inspired UI redesign (SF fonts, glass, whitespace) — persisted in `design-system/veralify/MASTER.md`.
- Day/Night theme mode: auto (time-based) + manual toggle; stars-at-night / sun+clouds-at-day; no-flash SSR script.
- Auth fully on **Supabase Auth** (Privy removed): Email+password, Google & Apple OAuth, **Passkeys/WebAuthn**.
- Booking.com-style `AuthModal` + flag-grid `LanguageModal` (both portal-rendered).
- i18n: 6 locales (en/es/fr/de/it/ar incl. RTL), server-rendered to avoid flash.
- Waitlist flow: landing form → `/api/waitlist`, `/api/waitlist-count`, referral codes, `/welcome` page, `/unsubscribe`.
- Legal pages: `/privacy`, `/terms`. Dashboard shell + newsletter control.
- API routes: `v1/chat/completions` (AI gateway), `waitlist`, `waitlist-count`, `unsubscribe`.
- Build fixed: lazy Supabase admin client (no build-time env throw); hydration warning resolved.

**Remaining for MVP**
- [ ] Payments / checkout UI (Stripe) on web.
- [ ] Authenticated dashboard depth (orders, eSIMs, profile management).
- [ ] Passkey enrollment UX polish + OTP auto-fill flow.

## 📱 iOS App (Swift / SwiftUI — `veralify-App/iOS`)

**Done**
- Auth: `LoginView` + `AuthViewModel`, Supabase client with **Google & Apple** sign-in.
- AI Concierge: `VeralifyAgent` + `VeralifyAgentManager` + tool registry (`Chat` feature, eSIM/Flight cards).
- Explore: countries, plans, detail views + view models.
- Purchase: `CheckoutView`, `ESIMInstallView` + view models.
- MyESIMs: list + detail + view model.
- Profile: profile, language settings, order history.
- Core infra: `ESIMGoClient`, `ESIMProvisioningManager`, `LocalOrderStore` (offline), `KeychainManager`, localization, theming (`AppTheme`, `FloatingNavBar`, `GlowBackground`).

**Remaining for MVP**
- [ ] Passkeys (WebAuthn / Face ID) enrollment.
- [ ] APNs push notifications (device token registration + handling).
- [ ] Stripe payment integration in checkout.
- [ ] Supabase Realtime for live order status (replace polling).
- [ ] Confirm SwiftData/CoreData offline persistence of eSIM QR/LPA + tickets.

## ⚙️ Backend (Supabase — Postgres · Edge Functions · RLS)

**Done**
- 17 migrations incl. `profiles` (+ `subscription_tier`, `monthly_ai_credits`, `stripe_customer_id`), `ai_usage_logs`, `user_orders`, `esim_orders`, referral/waitlist, **`webauthn_credentials`** (passkeys).
- 7 Edge Functions: `passkey`, `vera-users-api`, `vera-signup-submit`, `vera-newsletter-api`, `vera-newsletter-subscribe`, `vera-blog-api`, `vera-user-sync`.
- AI gateway (`/api/v1/chat/completions`) with credit guardrail via `profiles.monthly_ai_credits` + `ai_usage_logs`.
- RLS on user-owned tables; service-role admin client for server guardrails.

**Remaining for MVP**
- [ ] **Stripe**: checkout + webhook function + `stripe_events` idempotency table + tier toggling.
- [ ] **APNs**: `user_push_tokens` table + DB webhook → push Edge Function on order-status change.
- [ ] **Realtime**: enable on `user_orders`/`esim_orders`.
- [ ] Consolidate legacy `vera_users` → `profiles` (migrate + drop).
- [ ] External-API edge caching (eSIM Go catalog, Duffel airports).

---

## Change Log

### 2026-07-23
- **Fix (prod crash):** "Application error: a client-side exception" on Vercel preview. Root cause = missing `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` on the deploy; `AuthWidget` (in navbar on every page) threw on mount. Made `createSupabaseBrowserClient()` return `null` when unconfigured and guarded all callers (`AuthWidget`, `AuthModal`, `passkey.ts`) so auth degrades gracefully instead of white-screening. **Action still required:** set both `NEXT_PUBLIC_*` Supabase env vars for the Vercel Preview/branch environment and redeploy.
- **Created this status file** (`docs/PROJECT_STATUS.md`) as the running project-state + change log.
- **Fix:** production build failure — made Supabase admin client lazy (`src/lib/supabaseAdmin.ts`) so `next build` no longer throws on missing env vars during page-data collection.
- **Fix:** React hydration warning — added `suppressHydrationWarning` to `<html>` in `src/app/layout.tsx` (theme no-flash script mutates `data-theme` pre-hydration).
- **Feature:** Day/Night theme mode — `src/theme/{ThemeProvider,ThemeToggle,DaySky}.tsx`, `.day-*` CSS in `globals.css`, wired into `layout.tsx`, `BaseNavigation.tsx`, `RainbowInspiredLanding.tsx`. Auto time-based + manual toggle. (commit `49e7940`)
- **UI/UX:** Apple-inspired full-site redesign persisted to `design-system/veralify/MASTER.md`. (commit `dc015f7`)
