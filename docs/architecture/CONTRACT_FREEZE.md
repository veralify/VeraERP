# Veralify Contract Freeze — v2.3

**Status:** FROZEN as of 2026-08-27
**Source of truth:** `docs/PIVOT_PLAN.md` (Specification v2.3)
**Change control:** Any change to a frozen contract requires an ADR in `docs/decisions/` + Architecture approval + QA/Security approval for schema/RLS changes.

## Frozen contracts (spec section → scope)

| # | Contract | Spec sections | Consumers |
|---|---|---|---|
| 1 | Database schema | §7–§19 (identity, goals, nutrition, progress, communities, social, messaging, live rooms, coaching, AI, subscriptions, notifications, security infra, moderation) | Backend, AI, iOS, Web |
| 2 | Indexes | §20 | Backend |
| 3 | RLS policy matrix + helper functions | §21–§27 (8 classes: SELF, PARENT-OWNED, GROUP-MEMBER, COACH-PERMISSION, PARTICIPANT, SERVER-ONLY, ADMIN, PUBLIC) | Backend, QA |
| 4 | Storage rules | §28 | Backend, iOS, Web |
| 5 | Agora authorization | §29–§32 (token server-side only; role changes server-authorized; app certificate never on client) | Backend, iOS, Web |
| 6 | Chat architecture | §33 (Postgres + Supabase Realtime) | Backend, iOS, Web |
| 7 | Commerce | §34 (StoreKit 2 iOS digital · Stripe Billing web digital · appAccountToken required), §34b (Stripe Connect marketplace, UNIQUE(session_id), frozen platform fee), §39 (webhooks) | Backend, iOS, Web |
| 8 | Entitlements | §35–§38 (single Pro tier + VERALIFY_COACH; keys are canonical strings; 3-day trial; no free tier) | All |
| 9 | API contracts | §51–§60 | Backend, iOS, Web |
| 10 | AI tool contract + response contract | §61, §63–§64 (allowlisted tools only; no arbitrary SQL) | AI, Backend |
| 11 | AI model policy + routing | §4–§6 (OpenRouter; policy-versioned; no hard-coded model IDs in feature code) | AI |
| 12 | AI food pipeline | §62 (provenance-first; deterministic Nutrition Engine; immutable historical logs) | AI, Backend |
| 13 | Notifications | §18, §68 (durable outbox: notification_jobs → pg_cron → notification-worker Edge Function → APNs/Resend; idempotent) | Backend |
| 14 | Privacy + retention matrix | §70 | All |
| 15 | Security requirements | §71 + §18b (audit_logs, idempotency_keys, deletion, exports, consent) | All |
| 16 | Repository architecture | §72 (no monorepo restructure before Phase 13) | All |
| 17 | Event taxonomy / observability | §92–§93 | Analytics, All |

## File ownership map (Agent → paths)

| Agent | Owns | Must not touch |
|---|---|---|
| A — Architecture (orchestrator) | `docs/architecture/`, `docs/decisions/`, `docs/PROJECT_STATUS.md` | app code (approves, doesn't write) |
| B — Backend | `supabase/migrations/`, `supabase/functions/` (except `ai-gateway`), `src/lib/api/` | `src/app`, `veralify-App/` |
| C — AI | `supabase/functions/ai-gateway/`, `src/lib/ai/` | migrations (requests via B) |
| D — iOS | `veralify-App/` | everything else |
| E — Web | `src/` (except `src/lib/api/`, `src/lib/ai/`) | `supabase/`, `veralify-App/` |
| F — QA/Security | tests everywhere (read all) — **veto power** on migrations/RLS/payments/Agora/AI security | silent architecture "fixes" |
| G — DevOps | `.github/workflows/`, `scripts/`, env validation | product logic |
| H — Design | `design-system/` | app code |
| I — Analytics | event taxonomy docs, PostHog config in owned areas | sensitive data collection |
| J — Docs | `docs/` (non-architecture) | rewriting architecture |

## Build order (frozen)

```
CONTRACTS (this doc) → parallel: [Backend │ AI │ Design │ DevOps] → [iOS │ Web] → Integration → QA/Security → Hardening → Release
```

## Existing functionality that MUST be preserved

- Film/Foto feature (web `src/app` film routes + iOS `Core/Film`, `Features/Films`, `FilmCameraSession`) — per spec §1
- Supabase auth (web SSR + iOS), waitlist, Resend emails, legal pages
- Existing Stripe checkout/webhook/portal plumbing (extended, not replaced)

## Legacy to be superseded (do not delete without ADR)

- iOS eSIM/travel concierge (`ESIMGoClient`, `ESIMProvisioningManager`, Duffel mocks, travel chat cards) — superseded by pivot; removal handled by iOS agent under ADR-002
- Old `docs/PROJECT_STATUS.md` content (eSIM-era) — replaced by pivot status

## External credentials required (blockers for live behavior — integration boundaries built regardless)

| Credential | Needed by | Env var(s) |
|---|---|---|
| OpenRouter API key | AI gateway | `OPENROUTER_API_KEY` |
| Agora App ID + App Certificate | agora-token function | `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE` |
| Stripe live/test keys + webhook secret | billing | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` |
| Stripe Connect enabled on account | marketplace | (dashboard config) |
| Apple IAP: App Store Connect products, Server Notifications V2 URL, App Store Server API key | iOS billing | `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`, `APPLE_BUNDLE_ID` |
| APNs key | notifications | `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` |
| PostHog project key | analytics | `NEXT_PUBLIC_POSTHOG_KEY` |
| Sentry DSN | observability | `SENTRY_DSN`, `NEXT_PUBLIC_SENTRY_DSN` |
| Food data provider key (per §9 provenance) | nutrition | `FOOD_DATA_PROVIDER_KEY` |
