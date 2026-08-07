# Veralify — Project Status & Change Log

_Single source of truth for project state and MVP progress. Updated on every meaningful change._

**Last updated:** 2026-08-07 15:12 (local)

> 📋 **Sprint task breakdown (agent-ready prompts):** [`docs/SPRINT_TASKS.md`](./SPRINT_TASKS.md)

---

## Overall Build Status (Repo-Derived · 2026-08-07)

**`[███████░░░] 68%`** — Core infrastructure built; payments and live API integrations remaining.

> Derived from actual code files across `src/` (57 files), `supabase/` (34 files), and `veralify-App/iOS/` (142 files). 277 total tracked files.

| Area | Progress Bar | % | Repo Reality |
|------|-------------|:-:|--------------|
| 🏛️ Legal / Corporate | `[██████████]` | **100%** | All PDFs committed: incorporation, UTR, HMRC dormant filing, M&A |
| 🏦 Banking / Stripe | `[████░░░░░░]` | **40%** | `stripe_customer_id` in schema only — no checkout code, no webhook function |
| ✈️ Duffel / Flights | `[██░░░░░░░░]` | **20%** | `searchFlights()` is hardcoded mock data — no `DuffelClient` exists |
| 📡 eSIM Go | `[███████░░░]` | **70%** | Real `ESIMGoClient.swift` + provisioning manager built; no live API key yet |
| 📱 iOS App | `[███████░░░]` | **70%** | All core screens built; missing Stripe SDK, APNs, Realtime, Passkeys |
| 🌐 Web Platform | `[████████░░]` | **75%** | Waitlist + auth + i18n live; missing Stripe UI + dashboard depth |
| ⚙️ Backend (Supabase) | `[██████░░░░]` | **60%** | 17 migrations + 7 edge functions; missing Stripe webhook, APNs, Realtime |

### ⚠️ Biggest Gaps vs. Previous Estimates
- **Duffel is 20%, not 80%** — `VeralifyToolRegistry.swift` returns hardcoded Emirates/Qatar/Turkish flights; no Duffel HTTP client exists anywhere in the repo.
- **Stripe is 40%, not 100%** — `stripe_customer_id` column exists in the DB, but `CheckoutViewModel` calls a simulated `checkoutService()` mock. No Stripe SDK, no webhook Edge Function.
- **eSIM Go catalog tool in AI concierge is still mocked** — `fetch_eSIM_Catalog` in `VeralifyToolRegistry` returns hardcoded bundles; `ESIMGoClient` (real) is used only in Explore/Purchase views.

---

## 🗺️ MVP To-Do — What Remains to Ship

Ordered by priority (blockers first). Every item here is **required** before a real paying user can complete a transaction.

### 🔴 CRITICAL — Blockers (App cannot take money without these)

#### Stripe — Payments
- [ ] **Backend:** Create `stripe_events` idempotency table (`supabase/migrations/`)
- [ ] **Backend:** Create `vera-stripe-webhook` Edge Function — verify signature, toggle `subscription_tier`, provision eSIM on payment success
- [ ] **iOS:** Replace mock `checkoutService()` in `VeralifyToolRegistry.swift` with real Stripe iOS SDK `PaymentSheet`
- [ ] **iOS:** Wire `CheckoutViewModel` to create a PaymentIntent via backend, handle result states
- [ ] **Web:** Build Stripe checkout UI in `src/app/` — PaymentElement or redirect to Stripe-hosted checkout
- [ ] **Web:** Add `/api/stripe/webhook` route handler for server-side event processing

#### Duffel — Live Flight Search
- [ ] **Backend:** Create `vera-duffel-search` Edge Function — proxy `offer_requests` to Duffel API with live token (keep key server-side)
- [ ] **Backend:** Create `vera-duffel-book` Edge Function — `orders` creation + Veralify 8–10% markup applied
- [ ] **iOS:** Replace mock `searchFlights()` in `VeralifyToolRegistry.swift` with real call to `vera-duffel-search` Edge Function
- [ ] **iOS:** Wire `FlightCardView` "Book" action → `vera-duffel-book` → Stripe checkout flow
- [ ] **Web:** Add flight search UI or wire AI concierge on web to call real Duffel Edge Function

#### eSIM Go — Live Credentials
- [ ] **Config:** Set live `ESIM_GO_API_KEY` in `AppConfig.swift` (or inject via build scheme / Supabase secret)
- [ ] **iOS:** Replace mock `fetch_eSIM_Catalog` in `VeralifyToolRegistry` with real `ESIMGoClient.getPackages()` call
- [ ] **Backend:** Move `ESIMGoClient` order placement server-side (Edge Function) to protect API key — iOS should call backend, not eSIM Go directly

---

### 🟡 IMPORTANT — Core UX gaps (needed for a polished launch)

#### Auth Polish
- [ ] **iOS:** Passkey (Face ID / WebAuthn) enrollment flow in `LoginView`
- [ ] **iOS:** OTP auto-fill (`.textContentType(.oneTimeCode)`) on email OTP field
- [ ] **Web:** Passkey enrollment UX polish in `AuthModal`

#### Push Notifications (APNs)
- [ ] **Backend:** Create `user_push_tokens` table + RLS policy
- [ ] **Backend:** Create `vera-apns-push` Edge Function triggered by DB webhook on `user_orders.status` change
- [ ] **iOS:** Register device for APNs on app launch, `POST` token to backend
- [ ] **iOS:** Handle incoming push payloads in `AppDelegate` / `UNUserNotificationCenter`

#### Supabase Realtime
- [ ] **Backend:** Enable Realtime publication on `user_orders` and `esim_orders` tables
- [ ] **iOS:** Replace polling in `MyESIMsViewModel` with Supabase Realtime channel subscription

#### Dashboard (Web)
- [ ] **Web:** Authenticated dashboard — orders list, eSIM management, profile editor (`src/app/dashboard/`)
- [ ] **Web:** Connect dashboard to `user_orders` + `esim_orders` Supabase tables

---

### 🟢 NICE TO HAVE — Polish & scalability (post-MVP)

#### Data & Performance
- [ ] **Backend:** Consolidate legacy `vera_users` table → `profiles` (migrate rows, drop table)
- [ ] **Backend:** Edge caching for eSIM Go catalogue and Duffel airport codes (~24h TTL)
- [ ] **Backend:** Rate limiting on AI gateway and booking Edge Functions

#### iOS
- [ ] **iOS:** SwiftData / CoreData offline persistence of eSIM QR codes (`LPA:1$...`) + flight tickets
- [ ] **iOS:** Supabase Realtime for live concierge streaming (replace polling in `ChatViewModel`)

#### AI Concierge
- [ ] **Web + iOS:** Replace mock SSE stream in `/api/v1/chat/completions` with real OpenAI streaming call
- [ ] **iOS:** Connect `VeralifyAgentManager` tool calls to live backend Edge Functions instead of `VeralifyToolRegistry` mocks

---

### 📊 MVP Completion Estimate by Area After All TODOs Done

| Area | Current | After TODOs | Key unlock |
|------|:-------:|:-----------:|------------|
| 🏦 Stripe | 40% | 100% | Webhook function + iOS PaymentSheet + web checkout |
| ✈️ Duffel | 20% | 100% | Edge Function + live token + iOS wiring |
| 📡 eSIM Go | 70% | 100% | Live API key + server-side proxy + AI tool wiring |
| 📱 iOS App | 70% | 95% | Stripe SDK + APNs + Passkeys + Realtime |
| 🌐 Web | 75% | 95% | Stripe UI + dashboard depth |
| ⚙️ Backend | 60% | 95% | Stripe webhook + APNs + Realtime + cleanup |

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

## 🧠 Product Strategy — Phase 1–3 (2026-08-07)

---

### Phase 1 — What Veralify Is

**Travel & telecom super-app.** AI concierge (Vera) that books flights (Duffel), activates global eSIMs (eSIM Go), and wraps everything in one native iOS experience.
> *"Your passport to a borderless world."*

#### ✅ 3 Core Value Propositions
1. **One-tap global connectivity** — Buy + natively install an eSIM for 190+ countries in seconds. No QR scanning, no physical SIM swaps. Apple `CTCellularPlanProvisioning` built in.
2. **AI concierge as the UI** — Users talk to Vera instead of filling forms. She finds flights, recommends eSIMs for the destination, and handles checkout in one conversational flow.
3. **Unified trip wallet** — Flights + eSIM + order history in one app, with offline access to QR codes and boarding passes. No juggling 3 apps at the airport.

#### 👤 Ideal Customer Profile
**"The Frequent Independent Traveler"** — age 25–40, digital-native professional or remote worker, 4–12 trips/year across multiple countries. Pain: roaming charges + app fragmentation. Device: iPhone. Willingness to pay: high for convenience.

#### ⚔️ Competitors & Unfair Advantage

| Competitor | Gap | Veralify edge |
|---|---|---|
| **Airalo** | eSIM store only, no AI, no flights | Veralify adds AI concierge + flights + unified wallet |
| **Google Flights** | No eSIM, no concierge, no post-booking connectivity | Veralify covers the full trip lifecycle |
| **Hopper** | Price prediction only, no eSIM, no concierge | Veralify's moat = combined workflow, not one feature |

---

### Phase 2 — Scoped PRD

**Core problem:** Frequent travelers waste time juggling 3–5 apps to plan, book, and stay connected abroad. Veralify gives them one AI-powered iOS app that activates their eSIM, assists with flights, and keeps everything offline-accessible — in under 2 minutes.

#### ✅ Must-Have MVP Features (3-week window)

| # | Feature | Status |
|---|---------|--------|
| 1 | **AI Concierge Chat** — natural language → flight results + eSIM cards | ✅ Built (mock data) → needs live APIs |
| 2 | **eSIM Purchase + Native 1-tap Install** — browse by country, buy, install | ✅ Built → needs live eSIM Go key |
| 3 | **Stripe Checkout** — single payment for eSIM (flight booking deferred) | ⚠️ Schema only → needs PaymentSheet + webhook |
| 4 | **My eSIMs + Order History** — offline QR backup, usage meter | ✅ Built → needs Realtime polish |

#### 🚫 Out of Scope for MVP (v2)
- Live Duffel flight booking (keep as AI suggestion → link to airline)
- Lounge access, chauffeur, hotels
- Web checkout UI (iOS-first)
- APNs push notifications
- Dashboard depth on web

#### 🗺️ Core User Flow: Landing → Value

```
1. Open app  →  Apple/Google sign-in (1 tap)
2. ChatHomeView  →  "I'm flying to Tokyo next week"
3. Vera responds:
     → FlightCardView  (results, tap → airline link)
     → eSIMCardView    ("Japan 5GB/15 days — £16.99")
4. Tap eSIM card  →  PlanDetailView
5. Tap "Buy"      →  CheckoutView (Stripe PaymentSheet)
6. Payment OK     →  ESIMInstallView (1-tap Apple native install)
7. MyESIMs tab    →  active eSIM · usage meter · offline QR backup
```

#### 📊 MVP Success KPIs

| KPI | 30-day target |
|-----|--------------|
| eSIM purchase conversion (view plan → checkout complete) | ≥ 8% |
| AI concierge engagement (DAU sending ≥1 message) | ≥ 60% |

---

### Phase 3 — Technical Architecture

#### 🛠️ Stack (Current + What's Missing)

| Layer | Choice | Status |
|-------|--------|--------|
| iOS App | Swift / SwiftUI | ✅ 142 files, all screens built |
| Web (marketing) | Next.js 15 + Tailwind + Vercel | ✅ Live at veralify.com |
| Database + Auth | Supabase (Postgres + RLS + Auth) | ✅ 17 migrations, 7 Edge Functions |
| Payments | Stripe iOS SDK + webhook | ⚠️ Schema only — needs PaymentSheet + `vera-stripe-webhook` |
| eSIM | eSIM Go API | ⚠️ Client built — needs live key + server-side proxy |
| Flights (v1 display) | Duffel API | ❌ Needs `vera-duffel-search` Edge Function |
| AI | OpenAI GPT-4o-mini streaming | ⚠️ Mock gateway built — needs real key wired in |
| Email | Resend + React Email | ✅ Live |

#### 🗃️ DB Schema — What Exists vs. What's Needed

```
✅ profiles          id, email, subscription_tier, monthly_ai_credits, stripe_customer_id
✅ esim_orders       id, user_id, package_id, order_reference, smdp_address, matching_id, status
✅ user_orders       id, user_id, order_type, reference_code, amount, currency, status
✅ ai_usage_logs     id, user_id, model_used, prompt_tokens, completion_tokens
✅ newsletter_subs   id, email, referral_code, referral_count, unsubscribe_token, locale
✅ webauthn_creds    id, user_id, credential_id, public_key

❌ stripe_events     id, stripe_event_id (UNIQUE), type, processed_at   ← idempotency, NEEDED
❌ user_push_tokens  id, user_id, apns_token, created_at                ← APNs, v2
```

#### ⚡ 3-Week Sprint to MVP

| Week | Focus | Done when |
|------|-------|-----------|
| **Week 1** | `stripe_events` table + `vera-stripe-webhook` Edge Function + iOS `PaymentSheet` wired to `CheckoutViewModel` | Users can pay for an eSIM |
| **Week 2** | eSIM Go live key + replace `fetch_eSIM_Catalog` mock + server-side order proxy Edge Function + OpenAI real key in AI gateway | Real eSIMs delivered after real payment |
| **Week 3** | `vera-duffel-search` Edge Function (display only) + replace `searchFlights` mock in iOS + TestFlight build | Shippable MVP on TestFlight |

---

## Change Log

### 2026-08-07
- **Product strategy added:** Phase 1–3 (value props, ICP, PRD, architecture) appended to status file.
- **Status audit:** Full repo-derived progress breakdown added. Audited all 277 tracked files. Corrected Duffel 80%→20%, Stripe 100%→40%, eSIM Go confirmed 70%. Overall MVP ~68%.
- **MVP To-Do added:** Full prioritised checklist of remaining work to reach MVP — covering Stripe (payments + webhooks), Duffel (live Edge Functions + iOS wiring), eSIM Go (live key + server-side proxy), APNs, Realtime, Auth polish, and Dashboard.

### 2026-07-23
- **Fix (prod crash):** "Application error: a client-side exception" on Vercel preview. Root cause = missing `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` on the deploy; `AuthWidget` (in navbar on every page) threw on mount. Made `createSupabaseBrowserClient()` return `null` when unconfigured and guarded all callers (`AuthWidget`, `AuthModal`, `passkey.ts`) so auth degrades gracefully instead of white-screening. **Action still required:** set both `NEXT_PUBLIC_*` Supabase env vars for the Vercel Preview/branch environment and redeploy.
- **Created this status file** (`docs/PROJECT_STATUS.md`) as the running project-state + change log.
- **Fix:** production build failure — made Supabase admin client lazy (`src/lib/supabaseAdmin.ts`) so `next build` no longer throws on missing env vars during page-data collection.
- **Fix:** React hydration warning — added `suppressHydrationWarning` to `<html>` in `src/app/layout.tsx` (theme no-flash script mutates `data-theme` pre-hydration).
- **Feature:** Day/Night theme mode — `src/theme/{ThemeProvider,ThemeToggle,DaySky}.tsx`, `.day-*` CSS in `globals.css`, wired into `layout.tsx`, `BaseNavigation.tsx`, `RainbowInspiredLanding.tsx`. Auto time-based + manual toggle. (commit `49e7940`)
- **UI/UX:** Apple-inspired full-site redesign persisted to `design-system/veralify/MASTER.md`. (commit `dc015f7`)
