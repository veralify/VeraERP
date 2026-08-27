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
