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
