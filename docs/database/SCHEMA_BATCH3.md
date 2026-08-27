# Phase 1 Database Foundation — Batch 3

## Tables

- Coaching: `coach_profiles`, `coach_specialties`, `coach_clients`, `coach_client_permissions`, `coach_availability`, `coach_sessions`, `session_bookings`, `session_notes`, `coach_reviews`
- AI: `ai_conversations`, `ai_messages`, `ai_requests`, `ai_model_runs`, `ai_tool_calls`, `ai_food_estimates`, `ai_insights`, `ai_recommendations`, `ai_feedback`
- Commerce/subscriptions/IAP/Connect: `plans`, `billing_products`, `plan_entitlements`, `subscriptions`, `subscription_events`, `iap_transactions`, `user_entitlements`, `coach_stripe_accounts`, `session_payment_intents`, `coach_transactions`, `coach_payouts`, `coach_platform_fees`, `refunds`
- Notifications: `notifications`, `notification_preferences`, `notification_jobs`
- Moderation: `reports`, `moderation_actions`

## RLS ownership classification

| Table | Class |
|---|---|
| `coach_profiles`, `coach_specialties`, `coach_availability`, `coach_reviews` | Coach self-write; authenticated read where public/verified/involved |
| `coach_clients`, `coach_client_permissions` | COACH-PERMISSION/involved read; server-managed writes |
| `coach_sessions`, `session_bookings` | COACH-PERMISSION/involved read; booking/payment state server-managed |
| `session_notes` | COACH-PERMISSION; coach writes, shared notes readable by client when active grant exists |
| Batch 1 client data overlays | Coach read only with active relationship and explicit permission bit (`nutrition`, `weight`, `measurements`, `goals`, `progress_photos`, `activity`, `mood`) |
| `ai_conversations`, `ai_messages` | SELF / PARENT-OWNED |
| `ai_requests` | SELF read / SERVER write |
| `ai_model_runs` | PARENT-OWNED via `ai_requests.user_id` |
| `ai_tool_calls` | SERVER-ONLY |
| `ai_food_estimates`, `ai_insights`, `ai_recommendations`, `ai_feedback` | SELF read; limited user update/feedback insert |
| `plans`, `billing_products`, `plan_entitlements` | PUBLIC read product catalog |
| `subscriptions` | SELF read / SERVER write |
| `subscription_events`, `iap_transactions`, Connect ledger/payment tables | SERVER-ONLY |
| `user_entitlements` | SELF read / SERVER write; single normalized entitlement projection |
| `notifications`, `notification_preferences` | SELF |
| `notification_jobs` | SERVER-ONLY durable outbox |
| `reports` | SELF create + ADMIN read/update |
| `moderation_actions` | ADMIN |

## Helper functions

Implemented in Batch 3:

- `coach_can_access_client(coach_id, client_id)` — true only for active `coach_clients` rows with a permissions row.

Previously implemented helpers used by this batch:

- `is_platform_admin()` — `auth.jwt().app_metadata.role = platform_admin`.
- Batch 2 live-room/group helpers for coach live-room policy additions.

All new security-definer helpers set `search_path = public, pg_temp`, revoke `EXECUTE` from both `PUBLIC` and `anon`, then grant only to `authenticated`.

## Commerce invariants

- `session_bookings.status` is the frozen booking/payment state enum: `pending`, `payment_required`, `paid`, `confirmed`, `completed`, `cancelled`, `refunded`.
- `session_bookings.payment_method` is constrained to `stripe` only at launch.
- `session_payment_intents.session_id` is unique: exactly one payment intent per coach session.
- `session_payment_intents.platform_fee_cents` is immutable after insert.
- `coach_platform_fees.percentage` is configuration only; historical payment intent fees are never recalculated.
- `iap_transactions` stores `user_id`, `apple_original_transaction_id`, and `apple_transaction_id` for appAccountToken linkage and uniqueness.

## Notification outbox

`notification_jobs` includes `status`, `attempts`, `max_attempts`, `scheduled_at`, `next_attempt_at`, `sent_at`, `failed_at`, `last_error`, `idempotency_key_id`, `dead_letter_at`, and `dead_letter_reason`.

Claim-batch index: `idx_notification_jobs_claim_batch` on `(status, next_attempt_at, scheduled_at, attempts)` for queued/failed rows. A later Edge Function should be invoked by pg_cron every minute and claim rows with `FOR UPDATE SKIP LOCKED LIMIT 50`.

## Ambiguities resolved

- Plan catalog tables are public/auth readable product metadata; payment/webhook/ledger tables remain server-only except `subscriptions` and `user_entitlements` self-read.
- `coach_client` live rooms now reference `coach_sessions`; participant insertion for coach/client is allowed only for involved users as listeners.
- Session bookings are readable by involved coach/client but payment state transitions are server-authorized.
- Reports can be created by reporters but read/processed only by platform admins.

## Running locally

```bash
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase db reset --local
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase test db
SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io supabase gen types typescript --local > src/lib/api/database.types.ts
pnpm exec tsc --noEmit
```
