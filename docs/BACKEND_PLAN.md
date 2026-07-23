# Veralify Backend Plan — Supabase Unified Architecture

_Last updated: 2026-07-23_

## Verdict

**Yes, use your existing Supabase instance.** It serves as the single source of
truth for both the iOS App (SwiftUI) and the Web Platform (Next.js / Vercel).
The core task is architectural **consolidation and hardening**, not a rebuild.

Retiring Privy and standardizing fully on Supabase Auth removes user-syncing
overhead, eliminates duplicated auth code, and enables enterprise-grade
"Big Tech" auth mechanics across clients.

---

## Current State (Verified in Repo)

- ✅ **iOS Client:** Direct calls to Supabase Auth & REST
  (`SupabaseClient.swift`, `BackendService.swift`).
- ✅ **Database:** 16 SQL migrations, initial RLS implementation, and `profiles`
  mapped to `auth.users`.
- ✅ **API Layer:** 6 Edge Functions handling serverless logic
  (`vera-users-api`, `vera-signup-submit`, `vera-newsletter-api`,
  `vera-newsletter-subscribe`, `vera-blog-api`, `vera-user-sync`).
- ⚠️ **Identity Fragmentation:** Dual system detected (Privy in
  `src/components/layout/BaseNavigation.tsx` + Supabase Auth) →
  **Migrating to 100% Supabase Auth**.
- ⚠️ **Data Model Split:** Legacy `vera_users` vs `profiles` →
  **Standardizing on `profiles`**.

---

## Target Architecture

```text
  iOS (SwiftUI + SwiftData)      Web (Next.js / Vercel)
            \                           /
             ▼                         ▼
         Supabase Auth (Passkeys · Native OAuth · Passwordless OTP)
                         │
         Supabase Edge Functions (API Gateway & Secret Vault)
                         │
     ┌───────────────────┴───────────────────┐
     ▼                                        ▼
Postgres + RLS + Storage + Realtime      Third-Party Integrations
(Profiles, Orders, Invites, Tokens)      (OpenAI, Duffel, eSIM Go, Stripe, APNs)
```

**Core Security Rule:** Third-party provider secrets (OpenAI, Duffel, eSIM Go,
Resend, Stripe) reside strictly within Supabase Edge Function environment
variables. They must **never** be exposed to the iOS bundle or the web client.

---

## Migration & Execution Steps

### 1. Big Tech Unified Authentication (Zero-Friction Strategy)
Replicate the zero-password, frictionless auth flows used by Apple, Uber, and Stripe.

- **Native Sign in with Apple (iOS):** Use Apple's native `AuthenticationServices`
  framework to trigger system sheets directly **without WebViews**, completing
  auth via Supabase `signInWithIdToken` (mandatory for App Store Guideline 4.8).
- **Passkeys (WebAuthn / Face ID / Touch ID):** Passkey enrollment allows instant
  biometric logins across Web and iOS.
- **Passwordless 6-Digit Email OTP (Auto-Fill enabled):** Prefer 6-digit OTP codes
  over slow magic links. Configure the SwiftUI `TextField` with
  `.textContentType(.oneTimeCode)` so the iOS keyboard auto-detects and inserts
  incoming codes with one tap.
- **Server-Side Auth (Web PKCE flow):** Replace `@privy-io/react-auth` in Next.js
  with `@supabase/ssr` middleware for secure server-side session handling.
- **Progressive Profiling:** Collect only the identity token/email at signup.
  Collect names, preferences, and phone numbers post-login during onboarding.
- **Biometric App Lock (iOS):** Trigger local Face ID / Touch ID verification when
  returning to the app to unlock the active Supabase session securely.

### 2. Schema Standardization & Security
- Standardize on `public.profiles` keyed by `auth.users.id`.
- Migrate legacy data from `vera_users` into `profiles`, then drop `vera_users`.
- Enforce strict Row Level Security (RLS) across all user-owned tables:
  `profiles`, `user_orders`, `esim_orders`, `invitations`, `ai_usage_logs`,
  and `user_push_tokens`.

### 3. Consolidated Edge API Surface
- Every Edge Function authenticates incoming calls by validating
  `Authorization: Bearer <supabase_jwt>` and enforces RLS.
- Restrict `service_role` and `VERA_ADMIN_API_KEY` strictly to trusted
  server-to-server operations (never in app or browser).

### 4. Payments, Subscription & Entitlements
- **Stripe Webhook Function:** Listens for payment events, verifies signature
  and **idempotency via a `stripe_events` table**, and toggles
  `subscription_tier` (e.g. `standard` vs `veralify_black`).
- **Storage:** Allocate Supabase Storage buckets for static travel documents
  and user uploads with strict RLS policies.

---

## Critical Architecture Additions (Travel App Specifics)

### 📲 1. Offline-First Resilience (iOS Local Caching) — Must-Have
Travelers frequently lose network access on arrival in a new country and still
need to open their eSIM QR code or boarding pass.
- **iOS:** Persist active eSIM activation strings (`LPA:1$...`), QR codes
  (Base64), and flight tickets locally using **SwiftData / CoreData** upon
  purchase confirmation.
- **Backend:** Provide `Cache-Control` headers in Edge Functions so clients can
  serve the last-known-good response when offline.

### 🔔 2. Push Notifications Engine (APNs) — Must-Have
Lounge access, chauffeur arrival, and gate updates must alert users in time.
- Add a `user_push_tokens` table linking `user_id` → `apns_token`.
- Create a **Supabase Database Webhook** that invokes an Edge Function to send
  via Apple Push Notification service (APNs) on order-status changes.

### 💳 3. Idempotent Stripe Webhooks — Must-Have
Stripe may resend the same webhook on transient failures, risking double AI
credits or duplicate eSIM provisioning.
- Use a `stripe_events` table to guarantee each `event_id` is processed exactly
  once (idempotency-key verification) before applying side effects.

### ⚡ 4. Realtime Order Status Updates — Nice-to-Have
Replace REST polling with Supabase Realtime WebSockets so the UI updates the
instant an order status changes.

```swift
// iOS Swift example
let channel = supabase.channel("public:user_orders")
channel.onPostgresChanges(
    event: .update,
    schema: "public",
    table: "user_orders",
    filter: "user_id=eq.\(userId)"
) { change in
    // Update UI instantly when status changes to 'completed'
}
```

### 🔒 5. Invite-Only & Waitlist Engine — Nice-to-Have
Maintain `invitations` and `waitlist` tables with helper functions for referral
points and VIP access unlocking (the FOMO / exclusive-access flow).

### 🗂️ 6. Edge Caching for External APIs — Nice-to-Have
The eSIM Go catalog and Duffel airport codes rarely change minute-to-minute.
Cache these query results in Supabase Postgres for ~24h to cut external API
usage and speed up client responses.

---

## Guardrails (Already Scaffolded)

- Enforce `monthly_ai_credits` and log to `ai_usage_logs` before OpenAI calls.
- Add rate limiting on AI and booking Edge Functions.

---

## Production Stack & Scalability Map

| Layer | Provider | Free Tier Capability | Upgrade / Scale Path |
|---|---|---|---|
| Auth, DB & Realtime | Supabase | 50k MAU, 500 MB DB | Pro ($25/mo) + Read Replicas |
| Edge Functions | Supabase | 500k invocations/mo | Auto-scaling per 1M invocations |
| Web Hosting | Vercel | Hobby Tier | Pro Tier ($20/mo) |
| Email Transport | Resend | 100 emails/day (HTML branded) | Pro Tier ($20/mo) |
| Payments | Stripe | Pay-as-you-go | Pay-as-you-go |
| AI Orchestration | OpenAI / Claude | Usage-based | Dedicated tier / self-hosted proxy |

### Additional scale levers
- Supavisor pooling for connection spikes.
- Move heavy AI work to background jobs (pg_cron / queue).
- CDN caching on Edge Functions.

---

## Decisions

- **Identity source of truth:** Supabase Auth only (chosen 2026-07-23).
- **Authentication Model:** Passwordless & Biometric-First (Native Apple OAuth +
  Passkeys + 6-Digit Auto-fill OTP). Privy fully deprecated.

---

## Phase 1 Progress — Auth Consolidation (2026-07-23)

**Done (web):**
- Removed `@privy-io/react-auth`; added `@supabase/ssr` + `@simplewebauthn/browser`.
- Added SSR Supabase clients (`src/lib/supabase/{client,server,middleware}.ts`)
  and wired PKCE session refresh into `src/middleware.ts`.
- New auth UI: `AuthModal` (sign-in/sign-up) with **email + password**,
  **Google OAuth**, and **passkeys**; `AuthWidget` now shows live session state.
  Restyled to the site's blue/navy design tokens (replaced the clashing gold
  `authAccent`), verified via headless screenshots.
- Routes: `/auth/callback` (OAuth/magic-link code exchange) and `/auth/signout`.
- Passkeys: `webauthn_credentials` + `webauthn_challenges` migration and a
  `passkey` Edge Function (register/authenticate options+verify) that bridges to
  a Supabase session via `admin.generateLink` + `verifyOtp`.
- `.env.example` updated (dropped Privy; added `WEBAUTHN_RP_ID/RP_NAME/ORIGIN`).
- Verified: `tsc`, Biome, and `next build` all pass.

**Manual setup still required (dashboard / infra):**
- Supabase → Auth → Providers: enable **Google** (client ID/secret) and add
  `https://<domain>/auth/callback` to redirect URLs.
- Deploy the `passkey` function and run the new migration; set
  `WEBAUTHN_RP_ID`, `WEBAUTHN_RP_NAME`, `WEBAUTHN_ORIGIN` on the function.
- iOS: `SupabaseClient` already exposes `signInWithGoogle` / `signInWithApple`;
  wire the native buttons, `ASAuthorization`, OTP auto-fill, and biometric lock
  in a follow-up.
