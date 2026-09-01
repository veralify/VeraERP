# Veralify AI Gateway

```text
Web/iOS → Supabase Edge Function ai-gateway → safety pre-check → rate/cost guard
  → task router → model-policy.json role/fallback chain → OpenRouter
  → structured schema validation/repair/fallback → safety post-check → response
                                      ↘ ai_requests / ai_model_runs / ai_tool_calls metadata logs
```

## Env vars

- `OPENROUTER_API_KEY` (required; missing returns 503, no fake responses)
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- Optional: `AI_GATEWAY_PER_USER_PER_MINUTE`, `AI_GATEWAY_DAILY_COST_CEILING_USD`

## Routing and fallback

Feature code sends task-level requests only. `registry.ts` loads `model-policy.json` (`model_policy_version: 2026-08`) and `router.ts` maps task type to a role, then primary/fallback models. Provider retry handles 408/429/5xx/timeouts with exponential backoff; router fallback handles provider failures and over-budget runs.

## Adding a model

Edit only `supabase/functions/ai-gateway/model-policy.json`: add pricing, update a role's primary or fallback chain, and bump `model_policy_version` when policy changes. Do not touch feature code or `src/lib/ai`.

## Versioning

Every run stamps `model_policy_version`, `prompt_version`, `tool_schema_version`, and `safety_policy_version` into `ai_model_runs`. Prompts live under `prompts/` and carry version constants in `index.ts`.

## Local run

```bash
supabase functions serve ai-gateway --env-file .env
cd supabase/functions/ai-gateway && deno task test
```

The legacy `src/app/api/v1/chat/completions/route.ts` is still a mock eSIM/travel-compatible route; it should later delegate to this gateway after product integration.

## Food pipeline

```text
POST /analyze-food
  → safety/rate/cost checks
  → vision policy task food_image
  → structured FoodAnalysisResult (foods + portions only)
  → confidence thresholds from model-policy.json food_pipeline
      below verification_confidence_below → food_verification policy task
  → provenance lookup
      1. foods.barcode
      2. food_sources + food_external_mappings exact source/external_id
      3. normalized foods.name match
      4. external provider boundary (requires FOOD_DATA_PROVIDER_KEY; no fake data)
      5. ai_estimate_pending_verification
  → deterministic nutrition-engine.ts
      canonical food + current food_nutrition_versions + food_servings
      grams × canonical nutrient basis, rounded explicitly
  → response: resolved items include nutrition/provenance; unresolved items omit nutrition and set needs_verification
```

The AI never returns final nutrition numbers. It only identifies candidates and portions. `nutrition-engine.ts` computes calories/protein/carbs/fat/fiber/sugar/sodium from canonical data. Clients should use `buildFoodLogItemSnapshot()` from `src/lib/ai` to create immutable `food_log_items` snapshots so historical logs do not change when canonical food data changes.

## Evaluation framework

The permanent §67 harness lives in `supabase/functions/ai-gateway/evals/`.

Run seeded food benchmark:

```bash
cd supabase/functions/ai-gateway
pnpm dlx deno run --allow-read --allow-write --allow-env evals/runner.ts evals/datasets/food_seed_text.jsonl
```

Run seeded reasoning benchmark:

```bash
pnpm dlx deno run --allow-read --allow-write --allow-env evals/runner.ts evals/datasets/reasoning_seed.jsonl
```

Reports are written to `evals/out/*.report.json` and `evals/out/*.report.md`. The runner uses mock case outputs unless `OPENROUTER_API_KEY` is set or `--real-openrouter` is passed; then it calls the real routed OpenRouter path. Metrics include identification accuracy, portion error %, calorie/protein/macro error %, confidence calibration buckets, structured-output validity, latency, and cost.

Regression gates:

- `tests/router_chaos_test.ts` verifies fallback-chain telemetry for provider outages, total failure, and over-budget cheaper-role fallback.
- `tests/model_policy_regression_test.ts` fails when roles/routes/pricing/thresholds change without bumping `model_policy_version`.

EXACT HUMAN ACTION REQUIRED for Phase 17: provide the 500+ real food-image benchmark dataset described in §67, covering restaurant, homemade, mixed dishes, drinks, desserts, international cuisines, poor lighting, partial meals, large/small portions, with expected canonical foods and nutrition/portion tolerances.

## Persistence, coach, insights, recommendations

Every production gateway call now creates an `ai_requests` row before model execution and records each model attempt in `ai_model_runs` with model/provider, policy/prompt/tool/safety versions, tokens, latency, estimated cost, success, and structured-output validity. Tool executions write `ai_tool_calls`. Non-persisted harness calls must pass an `aiRequestId` where possible; if absent, logging explicitly skips model/tool rows for tests/evals only.

`/chat` persists `ai_conversations` and `ai_messages`, assembles minimum caller-scoped context (profile, active goal, goal targets, 7-day nutrition summaries, weight trend, recent food logs), runs the health safety layer, and exposes only allowlisted tools. Cross-user tool arguments are rejected.

`/insight` builds insights from daily nutrition summaries and goal targets, validates structured output, and reuses an existing same-day user/type insight to avoid duplicates. `/recommendations` ranks prefiltered candidates and persists `ai_recommendations`. `/feedback` writes `ai_feedback`. `/analyze-food` persists `ai_food_estimates` with resolved candidates and verification state.

Guarded integration coverage: `tests/logging_integration_test.ts` writes and reads real AI logging tables when `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, an existing profile row, and `--allow-net` are available; otherwise it reports a skip and keeps local unit suites deterministic.

## Spec endpoint aliases and tool status

Canonical Edge Function paths now accept the §60 names as thin aliases:

| Spec endpoint | Gateway route | Status |
|---|---|---|
| `POST /api/v1/ai/chat` | `/chat` | Real coach chat with persistence, safety, context, tools |
| `POST /api/v1/ai/food-estimate` | `/food-estimate` → `/analyze-food` | Real food estimate pipeline |
| `POST /api/v1/ai/food-verify` | `/food-verify` | Real standalone verification using food verification prompt |
| `POST /api/v1/ai/insight` | `/insight` | Real nutrition insight |
| `POST /api/v1/ai/progress-analysis` | `/progress-analysis` | Real progress insight alias with progress prompt/task |
| `POST /api/v1/ai/recommendations` | `/recommendations` | Real candidate generation + AI ranking + persistence |
| `POST /api/v1/ai/feedback` | `/feedback` | Real `ai_feedback` write |

Tool status:

| Tool | Status |
|---|---|
| `get_user_profile`, `get_user_goals`, `get_active_goal`, `get_goal` | Real, caller-scoped |
| `get_daily_nutrition`, `get_today_nutrition`, `get_nutrition_history` | Real, caller-scoped deterministic summaries |
| `get_weight_history`, `get_weight_trend`, `get_measurements` | Real, caller-scoped progress data |
| `get_food_log`, `get_recent_food_logs`, `search_foods` | Real, caller-scoped/canonical reads |
| `get_user_groups`, `get_recent_posts`, `get_upcoming_sessions` | Real, caller-scoped social/coaching reads |
| `get_progress_summary`, `get_activity_summary`, `get_recommended_groups`, `get_live_rooms`, `get_coach_relationship` | `NOT_YET_AVAILABLE` until the corresponding aggregate/live-room/relationship services are finalized |
| Mutations: `create_food_log`, `update_food_log`, `delete_food_log`, `create_goal`, `update_goal`, `create_progress_entry`, `recommend_group`, `recommend_live_room` | `NOT_YET_AVAILABLE`; mutation policy remains server/application-owned pending product confirmation flows |
| External food provider lookup | Blocked on `FOOD_DATA_PROVIDER_KEY` and provider adapter selection |
| 500+ image eval dataset | Human-provided Phase 17 requirement |

Recommendations now generate prefiltered candidates server-side from real goal targets, nutrition summaries, weight trends, group membership, and stale-goal signals when callers do not provide candidates.
