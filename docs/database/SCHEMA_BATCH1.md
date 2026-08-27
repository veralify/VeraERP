# Phase 1 Database Foundation — Batch 1

## Tables

- Identity: `profiles`, `profile_preferences`, `profile_privacy`, `user_devices`, `user_blocks`
- Goals: `goals`, `goal_targets`, `goal_milestones`
- Nutrition: `food_sources`, `food_external_mappings`, `food_nutrition_versions`, `foods`, `food_servings`, `meal_groups`, `food_logs`, `food_log_items`, `daily_nutrition_summaries`
- Progress: `weight_entries`, `body_measurements`, `mood_entries`, `activity_entries`, `progress_photos`, `progress_videos`, `progress_milestones`
- Security/compliance: `audit_logs`, `idempotency_keys`, `data_deletion_requests`, `data_exports`, `consent_records`

## RLS ownership classification

| Table | Class |
|---|---|
| `profiles` | SELF (+ PUBLIC subset via `public_profiles`) |
| `profile_preferences`, `profile_privacy`, `user_devices` | SELF |
| `user_blocks` | SELF for blocker writes; involved-user read |
| `goals` | SELF |
| `goal_targets`, `goal_milestones` | PARENT-OWNED via `goals.user_id` |
| `food_logs`, `meal_groups`, `daily_nutrition_summaries` | SELF |
| `food_log_items` | PARENT-OWNED via `owns_food_log(food_log_id)` |
| `foods`, `food_servings`, `food_sources`, `food_external_mappings`, `food_nutrition_versions` | PUBLIC read / SERVER-ONLY write |
| `weight_entries`, `body_measurements`, `mood_entries`, `activity_entries`, `progress_photos`, `progress_videos`, `progress_milestones` | SELF |
| `audit_logs`, `idempotency_keys` | SERVER-ONLY |
| `data_deletion_requests`, `data_exports` | SELF create/read + SERVER-ONLY process |
| `consent_records` | SELF create/read |

## Helper functions

Implemented now:

- `set_updated_at()` — shared trigger function.
- `is_platform_admin()` — checks server-controlled JWT `app_metadata.role = platform_admin`.
- `owns_food_log(food_log_id uuid)` — parent ownership helper for `food_log_items`.

Deferred to later batches because their parent tables are not in Batch 1:

- `is_group_member(group_id)` and `is_group_admin(group_id)` — groups batch.
- `is_conversation_member(conversation_id)` — messaging batch.
- `is_room_participant(room_id)` — live rooms batch.
- `coach_can_access_client(coach_id, client_id)` — coaching batch.
- `owns_post(post_id)` — social batch.

All implemented security-definer helpers set `search_path = public, pg_temp`, revoke `EXECUTE` from `PUBLIC`, and grant only to `authenticated`.

## Notes

- Existing legacy `profiles` is extended in-place to preserve auth, waitlist, and Stripe fields.
- Profile visibility defaults are private for this batch per mission instructions, even though §7.1 listed `is_public DEFAULT true`.
- `food_log_items` includes `food_nutrition_version_id`, `sugar_g`, and `sodium_mg` to make nutrition history immutable and traceable.

## Running locally

```bash
supabase start
supabase db reset
supabase test db
supabase gen types typescript --local > src/lib/api/database.types.ts
```

If Docker cannot pull Supabase images because of local certificate trust, fix Docker registry trust and rerun the commands above.

## Local dev note (VPN/TLS interception)
If `supabase start` fails pulling from public.ecr.aws (x509 error behind Cisco Umbrella/corporate VPN), prefix commands with:
`SUPABASE_INTERNAL_IMAGE_REGISTRY=docker.io`
