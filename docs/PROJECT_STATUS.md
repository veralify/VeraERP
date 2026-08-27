# Veralify — Project Status (Pivot Build)

_Single source of truth for build state. Spec: `docs/PIVOT_PLAN.md` v2.3 (FROZEN — see `docs/architecture/CONTRACT_FREEZE.md`)._
_Legacy eSIM-era status archived at `docs/PROJECT_STATUS_LEGACY_ESIM_ERA.md`._

**Last updated:** 2026-08-27

## Overall completion

`[█░░░░░░░░░] ~5%` — Phase 0 complete (audit + contract freeze). Parallel workstreams launched.

## Phase state

| Phase | State |
|---|---|
| 0 — Read/Audit/Freeze | ✅ DONE (2026-08-27) |
| Contract freeze | ✅ FROZEN v2.3 |
| 1 — Database foundation | 🟡 IN PROGRESS (Agent B) |
| 2 — Auth | 🟡 partial (existing web SSR auth + iOS Supabase auth reused) |
| 3 — Commerce | ⬜ boundaries pending schema |
| 4 — AI Gateway | 🟡 IN PROGRESS (Agent C) |
| 5–10 — Food AI / Progress / Social / Chat / Agora / Coaching | ⬜ |
| 11 — iOS | 🟡 foundations queued (Wave 2) |
| 12 — Web | 🟡 foundations queued (Wave 2) |
| 13–19 — Notifications → Release | ⬜ |

## Completed domains

- Phase 0 artifacts: CONTRACT_FREEZE.md, ADR-001 (cash gap), ADR-002 (eSIM superseded), ownership map, backlog (session todo DB, 18 items)

## Active agents

| Agent | Workstream | Status |
|---|---|---|
| A — Architecture | orchestrating, contracts | active (orchestrator) |
| B — Backend | Phase 1 database foundation (migrations+RLS+tests) | launched |
| C — AI | AI Gateway (OpenRouter client, registry, routing, logging) | launched |
| G — DevOps | CI workflows, env validation | launched |
| H — Design | design tokens + component contract | launched |
| D — iOS | Wave 2: app shell → auth → entitlements | queued |
| E — Web | Wave 2: app shell, member dashboard foundations | queued |
| F — QA/Security | reviews after Wave 1 lands | queued |

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
