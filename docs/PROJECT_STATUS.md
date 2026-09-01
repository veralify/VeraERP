# Veralify — Project Status (Pivot Build)

_Single source of truth for build state. Spec: `docs/PIVOT_PLAN.md` v2.3 (FROZEN — see `docs/architecture/CONTRACT_FREEZE.md`)._
_Legacy eSIM-era status archived at `docs/PROJECT_STATUS_LEGACY_ESIM_ERA.md`._

**Last updated:** 2026-08-27

## Overall completion

`[████░░░░░░] ~40%` — Phase 0 + Phase 1 DB (146 RLS tests) + commerce rail (Stripe/Apple webhooks + entitlement projection) + AI gateway/food pipeline/coach chat/insights + web member app + iOS onboarding/home all landed. Agora token service, coach portal, iOS track tab in flight.

## Phase state

| Phase | State |
|---|---|
| 0 — Read/Audit/Freeze | ✅ DONE (2026-08-27) |
| Contract freeze | ✅ FROZEN v2.3 |
| 1 — Database foundation | ✅ DONE — 3 batches + commerce config, 15 domains, 146 pgTAP RLS tests, clean reset |
| 2 — Auth | 🟡 partial (web SSR + iOS Supabase auth reused; Apple Sign-In full flow pending) |
| 3 — Commerce | ✅ rail DONE (Agent B: stripe-webhook, apple-notifications V2, iap-validate, project_user_entitlements) 🟡 web billing UI + coach Connect onboarding in progress (Agent E) |
| 4 — AI Gateway | ✅ core + persistence DONE (registry/routing/safety/cost + real ai_* writes, /chat coach, /insight, /recommendations, /feedback — 28+ deno tests) 🟡 remaining tool coverage + spec-aliased routes in progress (Agent C) |
| 5 — Food AI | ✅ pipeline DONE (deterministic nutrition engine, provenance, /analyze-food, snapshot contract) · iOS camera flow in progress (Agent D) |
| 6–8 — Progress / Social / Chat | 🟡 schema+RLS done; web surfaces (track/goals/progress/groups) done; iOS surfaces in progress |
| 9 — Agora live | 🟡 schema done; token service + moderation endpoints in progress (Agent B) |
| 10 — Coaching | 🟡 schema done; web coach portal in progress (Agent E) |
| 11 — iOS | 🟡 onboarding + Home DONE (Agent D); Track tab (food logging + AI camera) in progress |
| 12 — Web | 🟡 landing/pricing/dashboard shell + member app (track/goals/progress/groups) DONE; billing + coach portal in progress |
| 13–19 — Notifications → Release | 🟡 notification_jobs outbox + worker in progress (Agent B) |

## Completed domains

- Phase 0: CONTRACT_FREEZE.md (17 contracts), ADR-001 (cash gap), ADR-002 (eSIM superseded), ownership map
- DB (Agent B): identity/goals/nutrition/progress/security-infra · communities/social/messaging/live-rooms · coaching/AI/commerce/notifications/moderation — 132 RLS tests
- AI (Agent C): OpenRouter gateway (model-policy.json v2026-08), food pipeline §62-63, evaluation framework + policy regression gate — 52 deno tests
- Design (H): tokens.json → tokens.css + Tokens.swift generator, component contracts
- DevOps (G): web/db/ios/functions CI + supabase deploy workflow, env validation
- Web (E): fitness landing + feature pages, Pro pricing (weekly/monthly/annual), dashboard shell, travel/eSIM removal
- iOS (D): 5-tab shell (＋ create), VeraTokens, StoreKit 2 + entitlements (appAccountToken), paywall, eSIM removal

## Active agents

| Agent | Workstream | Status |
|---|---|---|
| A — Architecture | orchestrating, verification, commits | active |
| B — Backend | Batch 4: commerce rail (webhooks, iap-validate, entitlement projection) | running |
| C — AI | AI persistence (ai_* tables), /chat coach, /insight, /recommendations | running |
| D — iOS | Onboarding wizard + Home dashboard | running |
| E — Web | Member app: track/goals/progress/groups | running |
| F — QA/Security | full review pass after commerce rail lands | queued |
| G — DevOps | idle (CI live) | done (wave 1) |
| H — Design | idle (tokens live) | done (wave 1) |

## Open architecture issues

- **ADR-001 (OPEN):** cash settlement ledger undefined — online-only payments until product decision.

## Security issues

- None recorded yet. RLS enforcement matrix frozen; QA agent holds veto.

## Test status

- Web: `pnpm check` (biome + tsc) — baseline passing pre-pivot.
- DB: pgTAP/RLS tests to land with Phase 1 migrations.
- iOS: XCTest target exists; suites to land with foundations.

## Deployment status

- Web: Vercel (existing). Supabase: linked project (existing). Local stack: Docker available.
- CI: none yet — Agent G building `.github/workflows/`.

## External credentials still required (integration boundaries built regardless)

OPENROUTER_API_KEY · AGORA_APP_ID/CERTIFICATE · STRIPE keys incl. Connect · Apple IAP (ASC products, Server API key, Notifications V2 URL) · APNs key · POSTHOG key · SENTRY DSN · FOOD_DATA_PROVIDER_KEY — full table in CONTRACT_FREEZE.md.

## Next merge candidates

1. `backend: identity + profiles + goals migrations with RLS`
2. `devops: CI pipeline (biome, tsc, build, migration dry-run)`
3. `design: token foundation`
4. `ai: gateway skeleton with model registry + policy config`
