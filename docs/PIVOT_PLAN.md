# Veralify Pivot Plan

> Master Technical Specification — the technical contract for the Veralify pivot.

**Product:** Veralify  
**Tagline:** Track. Connect. Transform.  
**Platforms:** iOS + Web  
**Architecture:** AI-first fitness tracking + social communities + live interaction + coaching  
**Backend:** Supabase  
**AI Gateway:** OpenRouter  
**Video:** Agora RTC  
**Payments:** Stripe  
**Email:** Resend  
**Web:** Next.js 15+ / TypeScript / Vercel  
**Mobile:** Swift / SwiftUI

**Specification status:** Production architecture — **frozen for Phase 0**  
**Specification version:** 2.6 (Cal AI-style Pro + paid VERALIFY_COACH tier + 1:1 coach marketplace at launch)  
**Date:** August 26, 2026

---

# 1. Product Definition

Veralify combines:

1. AI-powered food and nutrition tracking.
2. Goal and progress tracking.
3. Fitness communities.
4. Live video/audio fitness rooms.
5. Messaging.
6. Coach/client relationships.
7. AI-powered personal insights.
8. AI-powered recommendations.
9. Progress sharing.
10. Subscription-based premium features.

The product should feel like:

**Cal AI**
→ effortless tracking

**Clubhouse**
→ live community

**Veralify**
→ AI understands your journey and connects you with people, communities and coaches that help you stay accountable.

## Core loop

```text
TRACK
  ↓
AI UNDERSTANDS
  ↓
PERSONAL INSIGHT
  ↓
CONNECT
  ↓
COMMUNITY / COACH
  ↓
ACCOUNTABILITY
  ↓
TRANSFORM
  ↓
TRACK
```

---

# 2. Non-Negotiable Architecture Principles

## 2.1 PostgreSQL is the source of truth

Supabase PostgreSQL owns application state.

Agora owns media transport.

OpenRouter owns model inference.

Stripe owns payment processing.

No third-party service becomes the authoritative application database.

## 2.2 AI is replaceable

No feature may directly depend on a hard-coded model ID.

All AI requests go through:

```text
Veralify AI Gateway
```

The gateway selects the model.

## 2.3 AI cannot execute arbitrary SQL

AI can request allowlisted application tools.

Example:

```text
get_user_goals()
get_food_history()
get_weight_history()
create_food_log()
recommend_group()
```

The backend validates and executes the operation.

## 2.4 Authorization happens before execution

Every privileged operation follows:

```text
Authenticate
→ Authorize
→ Validate
→ Execute
→ Log
→ Return
```

## 2.5 Sensitive data is private by default

Default privacy:

- health data → private
- nutrition → private
- weight → private
- measurements → private
- progress photos → private
- coach data → permission controlled
- direct messages → private

## 2.6 Entitlements are centralized

Application code asks:

```text
hasEntitlement("ai_advanced")
```

not:

```text
subscription == "pro"
```

---

# 3. Technology Stack

## iOS

- Swift
- SwiftUI
- Swift Concurrency
- SwiftData for local/cache state where useful
- Supabase Swift SDK
- AVFoundation
- Vision/VisionKit
- HealthKit
- UserNotifications
- Agora iOS SDK
- Stripe SDK only where appropriate to the chosen billing flow

## Web

- Next.js 15+
- TypeScript
- React 19
- Tailwind CSS 4
- Supabase JS (`@supabase/ssr` + `@supabase/supabase-js`)
- Stripe.js
- Agora Web SDK
- Resend + React Email (existing `src/emails`)
- Tooling: pnpm, Biome (lint/format), Vercel Analytics/Speed Insights

## Backend

- Supabase PostgreSQL
- Supabase Auth
- Supabase Storage
- Supabase Realtime
- Supabase Edge Functions
- pgvector

Supabase provides a full PostgreSQL database underneath Auth, Storage, Realtime and Edge Functions, making it appropriate as Veralify's central backend.

## AI

- OpenRouter
- structured outputs
- tool calling
- model routing
- provider failover
- prompt caching
- model evaluation

## Video

- Agora RTC

## Messaging

**Primary:** Supabase Postgres + Realtime.

**Optional later:** Agora Chat if scale or feature requirements justify it.

## Payments

Dual commerce (see §34 — launch-blocking):

- **Apple IAP / StoreKit 2** — digital features in the iOS app (Pro/Coach digital tiers)
- **Stripe Billing / Checkout / Customer Portal / Entitlements / webhooks** — web subscriptions
- **Stripe Connect** — coach marketplace payments & payouts (1:1 person-to-person services)
- **App Store Server Notifications V2** — Apple subscription lifecycle

Stripe's current Entitlements system maps internal features to products and automatically creates/revokes customer entitlements as subscription state changes. Stripe recommends persisting active entitlements internally for fast access checks. Apple and Stripe both normalize into `user_entitlements`.

## Monitoring

- Sentry
- PostHog
- Supabase logs
- OpenRouter usage/cost telemetry
- Agora analytics

---

# 4. Production Model Policy — August 2026

Model IDs are **configuration, not code**. Each AI role is defined as a policy record:

```text
role
primary_model
fallback_models[]
allowed_providers[]
max_cost_per_request
latency_target_ms
benchmark_version
```

The lineup below is the August 2026 configuration of that policy. It will change;
feature code must never hard-code any model ID.

## Production model roles

| Role | Model | OpenRouter ID | Primary purpose |
|---|---|---|---|
| Elite reasoning | GPT-5.6 Sol Pro | `openai/gpt-5.6-sol-pro` | Complex AI coach, deep analysis |
| Elite reasoning fallback | Claude Opus 5 | `anthropic/claude-opus-5` | Complex reasoning, verification |
| Multimodal primary | Gemini 3.7 Flash | `google/gemini-3.7-flash` | Food images, fast multimodal |
| Fast general | Gemini 3.6 Flash | `google/gemini-3.6-flash` | Chat, summaries, classification |
| Cheap multimodal | MiMo-V2.5 | `xiaomi/mimo-v2.5` | Low-cost image/video/audio tasks |
| Cheap agent/coding | MiMo-V2.5-Pro | `xiaomi/mimo-v2.5-pro` | Parallel coding/subagent work |
| Coding/review fallback | GPT-5.6 Sol | `openai/gpt-5.6-sol` | Coding, architecture, review |

### Current reference pricing

OpenRouter currently lists:

- GPT-5.6 Sol Pro: **$2/M input, $10/M output**
- Claude Opus 5: **$5/M input, $25/M output**
- Gemini 3.7 Flash: **$0.375/M input, $1.875/M output**
- Gemini 3.6 Flash: **$0.75/M input, $3.75/M output**
- MiMo-V2.5: approximately **$0.119/M input, $0.238/M output** at the current OpenRouter displayed rate.

Prices and provider availability are dynamic and must be treated as configuration rather than application constants.

## Why this lineup

### GPT-5.6 Sol Pro

Use for:

- complex personal analysis
- weekly/monthly progress analysis
- difficult nutrition reasoning
- AI coach
- high-value recommendations
- architecture/coding review

OpenRouter currently describes GPT-5.6 Sol Pro as GPT-5.6 Sol with `reasoning.mode=pro`, and it supports tool calling and structured outputs.

### Claude Opus 5

Use for:

- second-opinion reasoning
- complex coaching conversations
- verification
- code review
- difficult AI evaluations
- safety-sensitive reasoning

Claude Opus 5 supports images, tools and structured outputs and has a 1M context window.

### Gemini 3.7 Flash

Use as the default high-volume multimodal model.

Use for:

- food photos
- meal images
- progress-photo metadata
- image understanding
- simple AI conversations
- fast agent workflows

Gemini 3.7 Flash is currently listed by OpenRouter as multimodal, with a 1M context window and substantially lower cost than the frontier reasoning models.

### Gemini 3.6 Flash

Use for:

- simple questions
- summaries
- notifications
- classification
- recommendation candidate generation
- lightweight chat

It supports text, image, video, file and audio input.

### MiMo-V2.5

Use for:

- inexpensive multimodal operations
- preprocessing
- secondary image analysis
- batch processing
- low-value AI requests

MiMo-V2.5 supports text, audio, image and video and has a 1M context window.

### MiMo-V2.5-Pro

Use for:

- parallel coding agents
- background engineering work
- inexpensive long-context agent tasks

---

# 5. AI Routing

The application must never call a model directly.

```text
Feature
  ↓
Veralify AI Gateway
  ↓
Task Router
  ↓
Model Policy
  ↓
OpenRouter
  ↓
Selected Model
  ↓
Validation
  ↓
Application
```

## Task routing

```text
food_image
→ Gemini 3.7 Flash
→ Claude Opus 5 verification only when confidence/disagreement threshold is exceeded

simple_chat
→ Gemini 3.6 Flash

advanced_chat
→ GPT-5.6 Sol Pro

weekly_analysis
→ GPT-5.6 Sol Pro
→ Claude Opus 5 fallback

cheap_multimodal
→ MiMo-V2.5

coding
→ Claude Opus 5
→ GPT-5.6 Sol Pro review

moderation
→ Gemini 3.7 Flash
→ stronger model only for ambiguous cases
```

OpenRouter supports model routing and provider failover, and its current Auto Router can route by task/cost-quality tradeoff. Veralify should use explicit task policies for critical health/product operations and allow Auto Router for selected non-critical workloads.

---

# 6. AI Data Policy

AI prompts must never contain unnecessary personal data.

Before an AI request:

```text
Raw database
    ↓
Context Builder
    ↓
Minimum required context
    ↓
Model
```

Example:

For:

> "How did I do this week?"

send:

```text
goal
7-day calories
7-day protein
weight trend
activity summary
relevant preferences
```

Do not send:

```text
entire user record
entire social graph
private messages
unrelated photos
```

---

# 7. Supabase Database Schema

All primary keys use UUID.

All tables include:

```text
created_at timestamptz
updated_at timestamptz
```

where applicable.

---

## 7.1 Identity

### `profiles`

```text
id uuid PK → auth.users.id
username text UNIQUE NOT NULL
display_name text
avatar_path text
bio text
height_cm numeric
activity_level text
timezone text
date_of_birth date
onboarding_completed boolean DEFAULT false
is_public boolean DEFAULT true
created_at timestamptz
updated_at timestamptz
```

### `profile_preferences`

```text
user_id uuid PK
dietary_preferences jsonb
fitness_preferences jsonb
notification_preferences jsonb
ai_preferences jsonb
units text DEFAULT 'metric'
created_at
updated_at
```

### `profile_privacy`

```text
user_id uuid PK
profile_visibility text
progress_visibility text
nutrition_visibility text
weight_visibility text
activity_visibility text
coach_data_visibility text
created_at
updated_at
```

### `user_devices`

```text
id uuid PK
user_id uuid FK
platform text
push_token text
app_version text
last_seen_at timestamptz
created_at
updated_at
```

### `user_blocks`

```text
blocker_id uuid
blocked_id uuid
created_at
PRIMARY KEY (blocker_id, blocked_id)
```

---

# 8. Goals

### `goals`

```text
id uuid PK
user_id uuid FK
type text
title text
description text
target_value numeric
starting_value numeric
unit text
start_date date
target_date date
status text
created_at
updated_at
```

### `goal_targets`

```text
id uuid PK
goal_id uuid FK
metric text
target_value numeric
unit text
period text
created_at
updated_at
```

### `goal_milestones`

```text
id uuid PK
goal_id uuid FK
title text
target_value numeric
achieved_at timestamptz
created_at
```

---

# 9. Nutrition

## Food data strategy (provenance-first)

The flagship feature depends on where food data comes from. This is formal
architecture, not an implementation detail:

```text
Barcode / search / photo
 ↓
Internal food cache (foods)
 ↓ (miss)
External food provider(s)
 ↓
Normalize
 ↓
Deduplicate
 ↓
Store provenance
 ↓
AI interpretation
```

Every nutrition number must answer: **"Where did this number come from?"**
This matters when an AI estimate is wrong and the user corrects it.

### `food_sources`

```text
id uuid PK
code text UNIQUE              -- usda | openfoodfacts | verified_internal | user_submitted | ai_estimated
name text
priority integer              -- dedupe/conflict resolution order
is_active boolean
created_at
```

### `food_external_mappings`

```text
id uuid PK
food_id uuid FK
food_source_id uuid FK
external_id text
last_synced_at timestamptz
UNIQUE (food_source_id, external_id)
```

### `food_nutrition_versions`

```text
id uuid PK
food_id uuid FK
version integer
nutrition jsonb               -- full macro/micro snapshot
change_reason text            -- provider_sync | user_correction | admin_fix | ai_estimate
changed_by uuid FK NULL
created_at
```

**Immutable historical nutrition:** three concepts are distinct and must never
be conflated:

```text
food identity  ≠  food nutrition version  ≠  user food estimate
```

A user's historical food log records the nutrition values **as logged**
(snapshot referencing the nutrition version used). If a provider later corrects
Chicken Breast from 310 → 295 kcal, entries logged at 310 stay 310 unless the
user deliberately reprocesses them. Nutrition version changes never silently
rewrite history.

### `foods`

```text
id uuid PK
source text
external_id text
name text
brand text
serving_size numeric
serving_unit text
calories numeric
protein_g numeric
carbs_g numeric
fat_g numeric
fiber_g numeric
sugar_g numeric
sodium_mg numeric
barcode text
metadata jsonb
created_at
updated_at
```

Unique index:

```text
(source, external_id)
```

### `food_servings`

```text
id uuid PK
food_id uuid FK
label text
grams numeric
created_at
```

### `meal_groups`

```text
id uuid PK
user_id uuid FK
name text
meal_type text
logged_at timestamptz
created_at
updated_at
```

### `food_logs`

```text
id uuid PK
user_id uuid FK
meal_group_id uuid FK NULL
logged_at timestamptz
source text
photo_path text NULL
notes text
created_at
updated_at
```

### `food_log_items`

```text
id uuid PK
food_log_id uuid FK
food_id uuid FK NULL
name text
quantity numeric
unit text
grams numeric
calories numeric
protein_g numeric
carbs_g numeric
fat_g numeric
fiber_g numeric
confidence numeric
ai_estimated boolean
created_at
updated_at
```

### `daily_nutrition_summaries`

```text
id uuid PK
user_id uuid FK
date date
calories numeric
protein_g numeric
carbs_g numeric
fat_g numeric
fiber_g numeric
water_ml numeric
meal_count integer
created_at
updated_at
```

Unique:

```text
(user_id, date)
```

---

# 10. Progress

### `weight_entries`

```text
id uuid PK
user_id uuid FK
weight_kg numeric
measured_at timestamptz
source text
notes text
created_at
```

### `body_measurements`

```text
id uuid PK
user_id uuid FK
measurement_type text
value numeric
unit text
measured_at timestamptz
created_at
```

Supported types:

```text
waist
chest
hips
thigh
arm
body_fat
muscle_mass
```

### `mood_entries`

```text
id uuid PK
user_id uuid FK
mood_score integer
energy_score integer
stress_score integer
notes text
recorded_at timestamptz
created_at
```

### `activity_entries`

```text
id uuid PK
user_id uuid FK
activity_type text
duration_minutes integer
calories_burned numeric
steps integer
source text
started_at timestamptz
created_at
```

### `progress_photos`

```text
id uuid PK
user_id uuid FK
storage_path text
captured_at timestamptz
visibility text DEFAULT 'private'
caption text
created_at
updated_at
```

### `progress_videos`

```text
id uuid PK
user_id uuid FK
storage_path text
duration_seconds integer
captured_at timestamptz
visibility text DEFAULT 'private'
caption text
created_at
updated_at
```

### `progress_milestones`

```text
id uuid PK
user_id uuid FK
goal_id uuid FK NULL
type text
title text
description text
achieved_at timestamptz
created_at
```

---

# 11. Communities

### `groups`

```text
id uuid PK
owner_id uuid FK
name text
slug text UNIQUE
description text
avatar_path text
cover_path text
type text
visibility text
goal_type text NULL
member_limit integer NULL
is_active boolean DEFAULT true
created_at
updated_at
```

### `group_members`

```text
group_id uuid FK
user_id uuid FK
role text DEFAULT 'member'
status text DEFAULT 'active'
joined_at timestamptz
PRIMARY KEY (group_id, user_id)
```

Roles:

```text
owner
admin
moderator
coach
member
```

### `group_rules`

```text
id uuid PK
group_id uuid FK
rule_text text
position integer
created_at
updated_at
```

### `group_invites`

```text
id uuid PK
group_id uuid FK
invited_by uuid FK
invited_user_id uuid FK NULL
token text UNIQUE
expires_at timestamptz
accepted_at timestamptz NULL
created_at
```

---

# 12. Social Feed

### `follows`

Backs the `followers` privacy level (§70). Without this table the privacy
vocabulary and database would not match.

```text
id uuid PK
follower_id uuid FK
followed_id uuid FK
status text DEFAULT 'active'   -- active | pending | blocked
created_at
UNIQUE (follower_id, followed_id)
```

### `posts`

```text
id uuid PK
author_id uuid FK
group_id uuid FK NULL
content text
post_type text
visibility text
status text DEFAULT 'published'
created_at
updated_at
```

### `post_media`

```text
id uuid PK
post_id uuid FK
storage_path text
media_type text
width integer
height integer
duration_seconds integer NULL
position integer
created_at
```

### `comments`

```text
id uuid PK
post_id uuid FK
author_id uuid FK
parent_comment_id uuid NULL
content text
status text DEFAULT 'published'
created_at
updated_at
```

### `post_likes`

```text
post_id uuid FK
user_id uuid FK
created_at
PRIMARY KEY(post_id, user_id)
```

### `comment_likes`

```text
comment_id uuid FK
user_id uuid FK
created_at
PRIMARY KEY(comment_id, user_id)
```

### `post_bookmarks`

```text
post_id uuid FK
user_id uuid FK
created_at
PRIMARY KEY(post_id, user_id)
```

---

# 13. Messaging

### `conversations`

```text
id uuid PK
type text
group_id uuid NULL
created_by uuid FK
created_at
updated_at
```

Types:

```text
direct
group
coach_client
```

### `conversation_members`

```text
conversation_id uuid FK
user_id uuid FK
role text
last_read_message_id uuid NULL
joined_at timestamptz
PRIMARY KEY(conversation_id, user_id)
```

### `messages`

```text
id uuid PK
conversation_id uuid FK
sender_id uuid FK
message_type text
body text
metadata jsonb
reply_to_id uuid NULL
created_at
edited_at timestamptz NULL
deleted_at timestamptz NULL
```

### `message_attachments`

```text
id uuid PK
message_id uuid FK
storage_path text
media_type text
size_bytes bigint
created_at
```

---

# 14. Live Rooms

### `live_rooms`

```text
id uuid PK
group_id uuid NULL
host_id uuid FK
coach_session_id uuid NULL
title text
description text
room_type text
status text
scheduled_at timestamptz
started_at timestamptz NULL
ended_at timestamptz NULL
max_participants integer NULL
agora_channel text UNIQUE
created_at
updated_at
```

### `live_room_hosts`

```text
room_id uuid FK
user_id uuid FK
role text
PRIMARY KEY(room_id, user_id)
```

### `live_room_participants`

```text
room_id uuid FK
user_id uuid FK
joined_at timestamptz
left_at timestamptz NULL
role text                     -- host | moderator | speaker | listener
speak_state text DEFAULT 'listener'
                              -- listener | request_to_speak | approved_speaker | speaking
hand_raised_at timestamptz NULL
PRIMARY KEY(room_id, user_id)
```

### `room_banned_users`

```text
room_id uuid FK
user_id uuid FK
banned_by uuid FK
reason text NULL
created_at
PRIMARY KEY(room_id, user_id)
```

### `room_moderation_events`

```text
id uuid PK
room_id uuid FK
moderator_id uuid FK
target_user_id uuid FK
action text                   -- mute | remove | ban | approve_speaker | revoke_speaker | dismiss_hand
metadata jsonb
created_at
```

These tables make rooms a **live social room system** (Clubhouse-grade:
raise-hand → approval → stage), not merely group video calls.

### `live_room_events`

```text
id uuid PK
room_id uuid FK
user_id uuid FK NULL
event_type text
metadata jsonb
created_at
```

---

# 15. Coaching

### `coach_profiles`

```text
id uuid PK → profiles.id
headline text
bio text
specialties text[]
certifications jsonb
years_experience integer
hourly_rate numeric
currency text
location text NULL
online_only boolean DEFAULT true
verification_status text
rating numeric
review_count integer
created_at
updated_at
```

### `coach_specialties`

```text
id uuid PK
coach_id uuid FK
specialty text
created_at
```

### `coach_clients`

```text
coach_id uuid FK
client_id uuid FK
status text
started_at timestamptz
ended_at timestamptz NULL
created_at
updated_at
PRIMARY KEY(coach_id, client_id)
```

### `coach_client_permissions`

```text
coach_id uuid FK
client_id uuid FK
nutrition boolean DEFAULT false
weight boolean DEFAULT false
measurements boolean DEFAULT false
goals boolean DEFAULT true
progress_photos boolean DEFAULT false
activity boolean DEFAULT false
mood boolean DEFAULT false
created_at
updated_at
PRIMARY KEY(coach_id, client_id)
```

### `coach_availability`

```text
id uuid PK
coach_id uuid FK
day_of_week integer
start_time time
end_time time
timezone text
is_active boolean DEFAULT true
created_at
updated_at
```

### `coach_sessions`

```text
id uuid PK
coach_id uuid FK
client_id uuid FK
title text
description text
session_type text
scheduled_at timestamptz
duration_minutes integer
status text
agora_channel text UNIQUE
created_at
updated_at
```

### `session_bookings`

```text
id uuid PK
session_id uuid FK
client_id uuid FK
status text                   -- see state machine below
booked_at timestamptz
cancelled_at timestamptz NULL
created_at
updated_at
```

Booking payment state machine (payment state is explicit — a booking must never
appear confirmed while payment failed):

```text
pending
  ↓
payment_required
  ↓
paid ──────────────→ refunded
  ↓
confirmed ─────────→ cancelled
  ↓
completed
```

Allowed transitions only; every transition is written by the server (never the
client) and audited.

### `session_notes`

```text
id uuid PK
session_id uuid FK
coach_id uuid FK
content text
visibility text
created_at
updated_at
```

### `coach_reviews`

```text
id uuid PK
coach_id uuid FK
client_id uuid FK
rating integer
review text
status text DEFAULT 'published'
created_at
updated_at
```

---

# 16. AI Database

### `ai_conversations`

```text
id uuid PK
user_id uuid FK
type text
title text
created_at
updated_at
```

### `ai_messages`

```text
id uuid PK
conversation_id uuid FK
role text
content jsonb
model text NULL
created_at
```

### `ai_requests`

```text
id uuid PK
user_id uuid FK
task text
request_id text UNIQUE
status text
model_requested text
model_used text
fallback_used boolean
created_at
completed_at timestamptz NULL
```

### `ai_model_runs`

```text
id uuid PK
ai_request_id uuid FK
model text
provider text
model_policy_version text     -- which routing policy produced this run (§4)
prompt_version text
tool_schema_version text
safety_policy_version text
input_tokens bigint
output_tokens bigint
reasoning_tokens bigint NULL
latency_ms integer
estimated_cost numeric
success boolean
structured_output_valid boolean
created_at
```

Every run records **which policy, prompt, tool schema and safety policy** it ran
under — "model X produced this answer" is insufficient for regression analysis
and AI debugging six months later.

### `ai_tool_calls`

```text
id uuid PK
ai_request_id uuid FK
tool_name text
arguments jsonb
result jsonb
success boolean
created_at
```

### `ai_food_estimates`

```text
id uuid PK
user_id uuid FK
food_log_id uuid NULL
image_path text
model text
result jsonb
confidence numeric
verified boolean
corrected_by_user boolean
created_at
```

### `ai_insights`

```text
id uuid PK
user_id uuid FK
type text
title text
body text
source_data jsonb
model text
valid_until timestamptz NULL
created_at
```

### `ai_recommendations`

```text
id uuid PK
user_id uuid FK
recommendation_type text
target_id uuid NULL
title text
reason text
model text
score numeric
dismissed_at timestamptz NULL
created_at
```

### `ai_feedback`

```text
id uuid PK
user_id uuid FK
ai_request_id uuid FK
rating integer
feedback text
created_at
```

---

# 17. Subscriptions

### `plans`

```text
id uuid PK
code text UNIQUE
name text
description text
is_active boolean DEFAULT true
created_at
updated_at
```

### `billing_products`

Commerce-provider identifiers live here — never inside `plans`:

```text
id uuid PK
plan_id uuid FK
provider text                 -- apple | stripe
provider_product_id text      -- StoreKit product ID or Stripe product ID
billing_period text           -- weekly | monthly | annual
is_active boolean DEFAULT true
created_at
UNIQUE (provider, provider_product_id)
```

Example rows for VERALIFY_PRO:

```text
(pro, apple,  com.veralify.pro.weekly,  weekly)
(pro, apple,  com.veralify.pro.monthly, monthly)
(pro, apple,  com.veralify.pro.annual,  annual)
(pro, stripe, prod_XXXX,                weekly)
(pro, stripe, prod_XXXX,                monthly)
(pro, stripe, prod_XXXX,                annual)
```

### `plan_entitlements`

```text
id uuid PK
plan_id uuid FK
lookup_key text
limit_value numeric NULL
limit_period text NULL
created_at
```

### `subscriptions`

```text
id uuid PK
user_id uuid FK
stripe_customer_id text UNIQUE
stripe_subscription_id text UNIQUE
plan_id uuid FK
status text
current_period_start timestamptz
current_period_end timestamptz
cancel_at_period_end boolean
created_at
updated_at
```

### `subscription_events`

```text
id uuid PK
stripe_event_id text UNIQUE
event_type text
payload jsonb
processed boolean DEFAULT false
created_at
processed_at timestamptz NULL
```

### `iap_transactions`

```text
id uuid PK
user_id uuid FK
apple_original_transaction_id text UNIQUE
apple_transaction_id text UNIQUE
product_id text
plan_id uuid FK
status text                    -- active | expired | revoked | grace_period
purchased_at timestamptz
expires_at timestamptz NULL
environment text               -- production | sandbox
raw_payload jsonb
created_at
updated_at
```

### `user_entitlements`

```text
id uuid PK
user_id uuid FK
lookup_key text
source text                    -- apple | stripe | admin | promo
active boolean
limit_value numeric NULL
expires_at timestamptz NULL
updated_at
```

`user_entitlements` is the **only** entitlement surface the application reads.
Apple (via `iap_transactions`) and Stripe (via `subscriptions`) both normalize
into it. Stripe remains authoritative for Stripe subscription status; Apple App
Store Server API remains authoritative for IAP status; the internal table is a
fast normalized cache.

---

# 18. Notifications

### `notifications`

```text
id uuid PK
user_id uuid FK
type text
title text
body text
data jsonb
read_at timestamptz NULL
created_at
```

### `notification_preferences`

```text
user_id uuid PK
social boolean
chat boolean
live boolean
coaching boolean
nutrition boolean
goals boolean
marketing boolean
created_at
updated_at
```

### `notification_jobs`

Durable push queue/outbox with retry behavior (SERVER-ONLY):

```text
id uuid PK
notification_id uuid FK
user_id uuid FK
provider text                 -- apns | email | web
attempts integer DEFAULT 0
scheduled_at timestamptz
sent_at timestamptz NULL
failed_at timestamptz NULL
last_error text NULL
created_at
```

Flow: `notification record → notification_jobs → worker → APNs/Resend`,
with exponential backoff on `attempts`.

**Worker definition (initial implementation — not left to chance):**

```text
notification_jobs (Postgres outbox)
        ↓
pg_cron (every minute)
        ↓
Supabase Edge Function (notification-worker)
        ↓
Claim batch: UPDATE ... SET status='processing'
             WHERE id IN (SELECT ... FOR UPDATE SKIP LOCKED LIMIT 50)
        ↓
Send (APNs via provider token / Resend)
        ↓
Update sent_at / failed_at / attempts / last_error
        ↓
Retry with exponential backoff (max 5 attempts → dead-letter status)
```

Supabase does not operate a durable background worker implicitly — this
pg_cron + Edge Function loop **is** the worker. At higher scale it may be
replaced by a dedicated queue without changing the outbox contract.

---

# 18b. Security & Compliance Infrastructure

These tables are **required** by the security/launch policy and must exist from
Phase 1.

### `audit_logs`

```text
id uuid PK
actor_id uuid FK NULL
action text
target_type text
target_id uuid NULL
ip_hash text NULL
request_metadata jsonb NULL
metadata jsonb NULL
created_at
```

Mandatory audit events:

```text
coach viewing client data
permission changes
admin actions
subscription changes
sensitive profile access
AI tool mutations
data export/deletion requests
```

### `idempotency_keys`

```text
id uuid PK
key text UNIQUE
scope text                    -- payment | ai_write | booking | food_log | webhook | notification
request_hash text
response jsonb NULL
status text                   -- pending | completed | failed
created_at
expires_at
```

Required for: payments, AI writes, bookings, food-log creation, notifications,
Stripe/Apple webhooks.

### `data_deletion_requests`

```text
id uuid PK
user_id uuid FK
reason text NULL
status text                   -- pending | scheduled | processing | completed | cancelled
requested_at timestamptz
scheduled_for timestamptz
completed_at timestamptz NULL
```

### `data_exports`

```text
id uuid PK
user_id uuid FK
status text                   -- pending | processing | ready | expired | failed
artifact_path text NULL      -- signed download artifact in private storage
requested_at timestamptz
completed_at timestamptz NULL
expires_at timestamptz NULL
```

### `consent_records`

```text
id uuid PK
user_id uuid FK
consent_type text             -- terms | privacy | health_data | marketing
version text
granted boolean
created_at
```

---

# 19. Moderation

### `reports`

```text
id uuid PK
reporter_id uuid FK
target_type text
target_id uuid
reason text
description text
status text
created_at
resolved_at timestamptz NULL
```

### `moderation_actions`

```text
id uuid PK
moderator_id uuid FK
target_type text
target_id uuid
action text
reason text
created_at
```

---

# 20. Database Indexes

Mandatory indexes:

```text
food_logs(user_id, logged_at DESC)

food_log_items(food_log_id)

daily_nutrition_summaries(user_id, date DESC)

weight_entries(user_id, measured_at DESC)

body_measurements(user_id, measured_at DESC)

progress_photos(user_id, captured_at DESC)

group_members(user_id, status)

posts(group_id, created_at DESC)

posts(author_id, created_at DESC)

comments(post_id, created_at)

messages(conversation_id, created_at DESC)

live_rooms(group_id, scheduled_at)

live_rooms(status, scheduled_at)

coach_clients(coach_id, status)

coach_clients(client_id, status)

coach_sessions(coach_id, scheduled_at)

coach_sessions(client_id, scheduled_at)

ai_requests(user_id, created_at DESC)

ai_model_runs(ai_request_id)

notifications(user_id, created_at DESC)

subscriptions(user_id, status)

user_entitlements(user_id, lookup_key, active)
```

---

# 21. RLS Architecture — Policy Matrix + Helper Functions

RLS must be enabled on all client-exposed tables.

Supabase's security model combines Postgres grants and RLS policies; exposed tables should have RLS enabled and policies explicitly define what authenticated users can access.

**Enforcement rule:** the QA/Security agent may **reject** a migration that
violates this matrix — not merely review it afterward.

## Policy classes

Every table must be classified as exactly one of:

```text
SELF              -- row has user_id owned by requester
PARENT-OWNED      -- ownership derived through a parent row
GROUP-MEMBER      -- access via group membership
COACH-PERMISSION  -- access via explicit coach_clients grant
PARTICIPANT       -- access via conversation/room participation
SERVER-ONLY       -- no client access; Edge Functions / service role only
ADMIN             -- platform admin role only
PUBLIC            -- readable by anyone (rare, explicit)
```

## Helper functions

Centralize complex checks in `SECURITY DEFINER` functions instead of
duplicating joins in every policy. **Every SECURITY DEFINER helper must satisfy
all of the following (enforced in review):**

```text
- fixed search_path (SET search_path = public, pg_temp)
- explicit EXECUTE grants (revoke from PUBLIC)
- no caller-controlled schema/table parameters
- owned by a dedicated non-login role where practical
- regression tests for privilege escalation
```

Required helpers:

```text
is_group_member(group_id)
is_group_admin(group_id)
is_conversation_member(conversation_id)
is_room_participant(room_id)
coach_can_access_client(coach_id, client_id)
owns_food_log(food_log_id)
owns_post(post_id)
is_platform_admin()
```

## 21.1 SELF policy

Applies to tables that carry `user_id` directly:

- food_logs
- weight_entries
- body_measurements
- mood_entries
- activity_entries
- goals
- progress_photos
- notifications

Rule:

```text
auth.uid() = user_id
```

Users can:

```text
SELECT own
INSERT own
UPDATE own
DELETE own
```

## 21.2 PARENT-OWNED policy

Child tables do **not** carry `user_id`; ownership is derived through the parent.
Never write `auth.uid() = user_id` against a table that has no `user_id` column.

`food_log_items` (parent: `food_logs`):

```sql
USING (
  EXISTS (
    SELECT 1 FROM food_logs fl
    WHERE fl.id = food_log_items.food_log_id
      AND fl.user_id = auth.uid()
  )
)
```

Equivalent parent chains (all use helper functions):

```text
food_log_items        → food_logs.user_id
goal_targets          → goals.user_id
goal_milestones       → goals.user_id
post_media            → posts → author / group visibility
comments              → posts → group visibility
message_attachments   → messages → conversations → members
session_notes         → sessions → coach_clients grant
ai_model_runs         → ai_requests.user_id
```

## 21.3 Matrix (required in every schema PR)

| Table | Class |
|---|---|
| profiles | SELF (+ PUBLIC subset via view) |
| food_logs, weight_entries, goals, progress_photos | SELF |
| food_log_items, goal_targets, goal_milestones | PARENT-OWNED |
| groups | PUBLIC (discoverable) / GROUP-MEMBER (private) |
| group_members, posts, comments, post_likes | GROUP-MEMBER |
| conversations, messages, message_reads | PARTICIPANT |
| live_rooms, live_room_participants | PARTICIPANT |
| coach_clients, sessions, session_notes | COACH-PERMISSION |
| subscriptions, iap_transactions, subscription_events | SERVER-ONLY |
| coach_stripe_accounts, session_payment_intents, coach_transactions, coach_payouts, refunds | SERVER-ONLY |
| audit_logs, idempotency_keys, notification_jobs | SERVER-ONLY |
| data_deletion_requests, data_exports | SELF (create/read) + SERVER-ONLY (process) |
| reports, moderation_actions | ADMIN (+ SELF create for reports) |
| foods, food_servings, food_sources | PUBLIC read / SERVER-ONLY write |
| follows | SELF (both directions readable by involved users) |

---

# 22. Group RLS

### Read group

User may read if:

```text
group.visibility = 'public'
```

OR:

```text
exists group_members
```

### Create post

Must be:

```text
active group member
```

### Update post

Must be:

```text
author
OR group admin
OR moderator
```

### Delete post

Same rule.

---

# 23. Chat RLS

A user can read a conversation only if:

```text
exists conversation_members
where user_id = auth.uid()
```

A user can send a message only if:

```text
exists conversation_members
AND sender_id = auth.uid()
```

A user can never directly modify another user's message.

Deletion should be soft deletion.

---

# 24. Coach RLS

Coach can access client data only if:

```text
coach_clients.status = 'active'
```

AND:

```text
coach_client_permissions.<field> = true
```

Example:

```text
coach wants weight data
→ relationship active
→ weight permission true
→ allow
```

Otherwise deny.

---

# 25. Live Room RLS

Room information:

- public if public room
- group members if private group room
- coach/client participants if private coaching session

Creating a room requires:

```text
group admin
OR group owner
OR coach authorized for session
```

Agora tokens are generated only after these checks.

---

# 26. Subscription RLS

Users may read their own:

```text
subscriptions
user_entitlements
```

Users cannot insert/update/delete either.

Only trusted server functions can modify them.

---

# 27. Admin RLS

Platform-admin operations require a server-side role claim.

Do not implement admin security using a client-side `is_admin` boolean.

Use:

```text
auth.jwt()
→ app_metadata.role
```

or an equivalent server-controlled authorization mechanism.

---

# 28. Supabase Storage

Buckets:

```text
avatars
food-images
progress-media
post-media
chat-media
coach-media
```

## Public

Only:

```text
avatars
```

if the user profile is public.

## Private

Everything else by default.

Private media is accessed through signed URLs.

---

# 29. Agora Architecture

Agora is responsible for real-time media.

Supabase is responsible for application authorization.

```text
iOS/Web
  ↓
POST /api/live/rooms/{id}/token
  ↓
Supabase Edge Function
  ↓
Authenticate
  ↓
Check room membership
  ↓
Check coach/session authorization
  ↓
Generate Agora token
  ↓
Return:
  channel
  uid
  token
  expiration
  role
  ↓
Agora RTC
```

Never expose the Agora App Certificate.

**Server-authorized role changes (mandatory):** Agora privileges always derive
from server-side room state — never client assertion:

```text
listener
 ↓
request_to_speak (client requests)
 ↓
moderator approves (server validates moderator)
 ↓
database changes speak_state
 ↓
new token / Agora privilege issued
```

The iOS/Web client can never decide "I'm now a speaker." A client with a
listener token that publishes audio is a protocol violation — tokens are scoped
to the database role at issuance.

---

# 30. Agora Room Naming

Use opaque internal IDs rather than human-readable secrets.

Example:

```text
vr_live_01JXYZ...
```

Do not use:

```text
fatloss
coach-room
johns-session
```

as security credentials.

The channel name is not authorization.

The token is authorization.

---

# 31. Agora Room Types

```text
group_checkin
community_room
coach_session
group_coaching
q_and_a
workout
```

## Group room

Participants:

```text
member
host
moderator
```

## Coach room

Participants:

```text
coach
client
```

## Group coaching

Participants:

```text
coach
clients
moderator
```

---

# 32. Agora Scaling

Initial:

```text
Agora RTC
```

Use live streaming architecture later if large public rooms require broadcaster/audience semantics.

Do not build recording/transcoding until product requirements justify it.

Agora currently lists RTC at usage-based pricing with the first 10,000 combined RTC minutes free each month; its Chat product has a free tier up to 500 monthly active users.

---

# 33. Chat Architecture

Primary:

```text
Postgres
+
Supabase Realtime
```

Flow:

```text
message
 ↓
RLS validation
 ↓
insert messages
 ↓
Realtime event
 ↓
recipient devices
```

Use Agora Chat later if:

- chat concurrency becomes very high
- advanced messaging capabilities justify it
- operational complexity becomes lower than maintaining the current system

---

# 34. Commerce Architecture — Cal AI-Style Single Subscription

**Pricing model (launch): exactly like Cal AI.**

```text
No free tier.
Onboarding quiz → personalized plan → hard paywall → 3-day free trial
→ one subscription: VERALIFY PRO
```

```text
VERALIFY PRO (consumer)
  Weekly:   $4.99 / week
  Monthly:  $9.99 / month
  Annual:   $29.99 / year  (default selection, "save 75%")
  Trial:    3 days free, auto-converts

VERALIFY COACH (coach tools)
  Weekly / Monthly / Annual — pricing is configuration
  Includes everything in Pro + coach dashboard, client management,
  client data access, scheduling, video/group sessions
```

Prices are App Store Connect / Stripe configuration, not code. Pro unlocks the
full consumer experience: AI food scanning, insights, unlimited groups, live
rooms, progress analytics, coach discovery.

**Launch-blocking rule:** the subscription unlocks digital app functionality,
so inside the iOS app it must be sold through **Apple In-App Purchase**. Apple
permits alternative payments only for **real-time person-to-person services
between two individuals** (e.g., 1:1 fitness training) — one-to-many services
remain IAP.

```text
                 VERALIFY BILLING
                        │
          ┌─────────────┴─────────────┐
          │                           │
   DIGITAL SUBSCRIPTIONS         HUMAN SERVICE
   VERALIFY_PRO (consumer)        PAYMENTS
   VERALIFY_COACH (coach tools)       │
          │                      Stripe Connect
   ┌──────┴──────┐               1:1 coach session
   │             │               Coach payouts
 iOS app       Web
   │             │
 Apple IAP    Stripe Billing
 (StoreKit 2) (Checkout/Portal)
   │             │
   └──────┬──────┘
          ↓
   user_entitlements   ← single normalized source
```

Rules:

1. iOS subscriptions (Pro + Coach) → StoreKit 2 (Pro: hard paywall after onboarding quiz).
2. Web subscriptions (Pro + Coach) → Stripe Billing.
3. 1:1 coach sessions (person-to-person, real-time) → Stripe Connect, allowed
   outside IAP per Apple's person-to-person services exception — **in launch scope** (§34b).
4. Group coaching (one-to-many) consumed in-app → IAP-gated (included in Pro).
5. The application only ever reads `user_entitlements` — it never cares whether
   an entitlement came from Apple or Stripe.
6. Never trust client-side subscription state.
7. Referral codes at the paywall (Cal AI-style growth loop) — free days per
   successful referral, configured server-side.

## Apple IAP layer

- StoreKit 2 products: `VERALIFY_PRO` (weekly + monthly + annual, 3-day intro
  trial) and `VERALIFY_COACH` (weekly + monthly + annual)
- App Store Server Notifications V2 → `POST /api/apple/notifications`
- Server-side receipt/transaction verification via App Store Server API
- `iap_transactions` table (see §17) feeding `user_entitlements` with `source = 'apple'`

**Account linking (mandatory):** every StoreKit subscription purchase must be
associated with a Veralify user through Apple's `appAccountToken`:

```text
Authenticated Veralify user
        ↓
StoreKit purchase (appAccountToken = veralify user uuid)
        ↓
Apple transaction
        ↓
iap_transactions (user resolved via appAccountToken)
        ↓
user_entitlements
```

The backend must never guess which Veralify account owns an Apple transaction.

**Restore purchases:** the iOS app restores access using StoreKit 2
`Transaction.currentEntitlements` — Apple's recommended mechanism for restoring
previously purchased functionality.

## Stripe products (web)

Create **two** products.

```text
VERALIFY_PRO
  Weekly   ($4.99)
  Monthly  ($9.99)
  Annual   ($29.99, default)
  3-day trial

VERALIFY_COACH
  Weekly / Monthly / Annual (configuration)
```

Pricing is intentionally configuration, not hard-coded into the application.

---

# 34b. Coach Marketplace Payments — Stripe Connect

> **Status: LAUNCH SCOPE.** Veralify's second revenue stream: clients pay
> coaches for 1:1 sessions; Veralify retains a platform fee. Built in
> Phase 10 (Coaching) alongside booking + video sessions.

Coaching is a **marketplace**, not just scheduling + video. Money flow:

```text
Client
  ↓ pays
Veralify (Stripe Connect platform)
  ↓
session_payment_intents
  ↓
Platform fee retained
  ↓
Coach payout (connected account)
```

### `coach_stripe_accounts`

```text
id uuid PK
coach_id uuid FK UNIQUE
stripe_account_id text UNIQUE
onboarding_status text        -- pending | complete | restricted
charges_enabled boolean
payouts_enabled boolean
created_at
updated_at
```

### `session_payment_intents`

```text
id uuid PK
session_id uuid FK UNIQUE     -- exactly one payment intent per session
client_id uuid FK
coach_id uuid FK
stripe_payment_intent_id text UNIQUE
amount_cents integer
currency text
platform_fee_cents integer    -- IMMUTABLE once created (frozen transaction value)
status text                   -- requires_payment | succeeded | refunded | failed
created_at
updated_at
```

The `percentage` in `coach_platform_fees` is the **configuration that produced**
`platform_fee_cents` — it is never recalculated against historical transactions.

### `coach_transactions`

```text
id uuid PK
coach_id uuid FK
session_payment_intent_id uuid FK NULL
type text                     -- charge | refund | payout | fee | adjustment
amount_cents integer
currency text
stripe_ref text
created_at
```

### `coach_payouts`

```text
id uuid PK
coach_id uuid FK
stripe_payout_id text UNIQUE
amount_cents integer
currency text
status text
period_start timestamptz
period_end timestamptz
created_at
```

### `coach_platform_fees`

```text
id uuid PK
coach_id uuid FK
percentage numeric            -- platform take rate (config, not code)
effective_from timestamptz
created_at
```

### `refunds`

```text
id uuid PK
session_payment_intent_id uuid FK
stripe_refund_id text UNIQUE
amount_cents integer
reason text
status text
requested_by uuid FK
created_at
```

Rules:

1. All marketplace tables are SERVER-ONLY (no client RLS access; coaches read
   their own transactions via views/API).
2. Payments, refunds and payouts require `idempotency_keys` (§18b).
3. Coach onboarding uses Stripe Connect hosted onboarding.
4. 1:1 session charges qualify for the Apple person-to-person exception; keep
   the purchase flow compliant (service consumed person-to-person in real time).

---

# 35. Entitlements — Single Tier

Cal AI model: **one subscription, everything included.** Entitlement keys still
exist so limits stay configurable and future tiers remain possible without
schema changes.

```text
ai_food_logging
advanced_ai
daily_summary
advanced_nutrition
unlimited_groups
advanced_progress
progress_photos
advanced_trends
live_rooms
premium_live_rooms
coach_discovery
```

---

# 36. Trial Entitlements

There is **no free tier**. The 3-day trial grants full Pro entitlements
(Apple intro offer / Stripe trial). When the trial lapses without conversion:

```text
read-only access to own historical data
paywall on all tracking, AI, groups and live features
```

---

# 37. Pro Entitlements

All keys in §35. No feature differentiation inside the paid tier.

---

# 38. Coach Model

**"Coach" is three separable concepts — do not tangle them:**

```text
1. Coach Account          -- role/identity: verified coach profile, discoverable
2. VERALIFY_COACH         -- paid subscription: coach dashboard, client management,
   (Coach Tools)             client data, scheduling, video/group sessions
                             (IAP on iOS / Stripe on web)
3. Coach Marketplace      -- Stripe Connect services: selling 1:1 sessions,
   Services                  receiving payouts (LAUNCH SCOPE, §34b)
```

Launch model:

```text
coach account   → coach_profiles row + platform verification (free, invited/vetted)
coach tools     → VERALIFY_COACH subscription → user_entitlements (coach_* keys)
marketplace     → coach_stripe_accounts (onboarded, payouts enabled)
```

A user may hold any combination simultaneously: a coach subscribing to tools,
a user purchasing coaching, a coach selling 1:1 services — or all three. The
entitlement model treats each independently.

VERALIFY_COACH entitlement keys (all Pro keys plus):

```text
coach_client_management
coach_client_data
coach_video_sessions
coach_group_sessions
coach_scheduling
coach_dashboard
```

Stripe's Entitlements model is specifically designed to map features to products and automatically update customer feature access as subscriptions change.

---

# 39. Billing Webhook Architecture

Two inbound billing webhooks, one normalized outcome.

## Stripe

Endpoint:

```text
POST /api/stripe/webhook
```

Process:

```text
Receive event
 ↓
Verify Stripe signature
 ↓
Check event ID
 ↓
Ignore duplicate
 ↓
Store subscription_event
 ↓
Process event
 ↓
Update local subscription
 ↓
Refresh entitlements
 ↓
Commit
```

Important events include:

```text
checkout.session.completed
customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
invoice.paid
invoice.payment_failed
entitlements.active_entitlement_summary.updated
```

Stripe does not guarantee webhook event ordering, so handlers must be idempotent and able to retrieve authoritative objects when necessary.

## Apple App Store Server Notifications V2

Endpoint:

```text
POST /api/apple/notifications
```

Process:

```text
Receive signedPayload (JWS)
 ↓
Verify signature chain
 ↓
Decode transaction / renewal info
 ↓
Check idempotency (notificationUUID)
 ↓
Upsert iap_transactions
 ↓
Refresh user_entitlements (source = apple)
 ↓
Commit
```

Key notification types: `SUBSCRIBED`, `DID_RENEW`, `DID_FAIL_TO_RENEW`,
`EXPIRED`, `GRACE_PERIOD_EXPIRED`, `REVOKE`, `REFUND`.

Both webhooks write through `idempotency_keys` (§18b) and converge on
`user_entitlements`.

---

# 40. iOS Screen Architecture

## Onboarding

### `WelcomeScreen`

- logo
- positioning
- Get Started
- Sign In

### `GoalSelectionScreen`

Choices:

- lose fat
- build muscle
- gain weight
- improve fitness
- improve nutrition
- build consistency

### `ProfileSetupScreen`

- height
- activity
- preferences
- units

### `TargetSetupScreen`

AI-assisted target setup ("your personalized plan").

### `PlanRevealScreen`

Cal AI-style: show the computed personalized plan (daily calories, macros,
projected goal date) as the payoff of the quiz.

### `PaywallScreen`

Hard paywall — required to proceed (no free tier):

- 3-day free trial, then $4.99/wk, $9.99/mo or $29.99/yr (annual preselected)
- StoreKit 2 purchase (appAccountToken)
- referral code entry
- restore purchases (currentEntitlements)

### `CommunitySetupScreen`

Recommended communities (post-purchase).

---

# 41. Home Screens

### `HomeView`

Sections:

```text
Header
Today's progress
Calories
Protein
Goal progress
AI insight
Streak
Live now
Community activity
Upcoming session
Recommended action
```

### `AIInsightCard`

Example:

```text
Your protein is 18g below today's target.

Add a protein-rich meal to finish the day strongly.
```

CTA:

```text
Ask AI
```

---

# 42. Track Screens

### `TrackView`

Tabs:

```text
Food
Progress
Goals
Trends
```

### `FoodLogView`

- breakfast
- lunch
- dinner
- snacks
- calories
- macros

### `FoodCameraView`

Primary CTA:

```text
Take Photo
```

### `FoodAnalysisView`

Shows:

```text
detected food
portion
calories
protein
carbs
fat
confidence
```

Actions:

```text
Confirm
Edit
Retake
```

### `BarcodeScannerView`

- barcode
- product lookup
- serving selection
- confirm

### `MealEditorView`

- ingredients
- portions
- macros
- notes

---

# 43. Progress Screens

### `ProgressDashboardView`

- weight chart
- goal progress
- streak
- measurements
- trends

### `WeightEntryView`

### `MeasurementsView`

### `ProgressPhotoView`

### `ProgressGalleryView`

### `GoalDetailView`

### `MilestonesView`

---

# 44. Connect Screens

### `ConnectView`

Tabs:

```text
Discover
My Groups
Live
Messages
```

### `GroupDiscoveryView`

Cards:

```text
goal
members
activity
live now
description
```

### `GroupDetailView`

```text
Header
Members
Feed
Live
Chat
About
```

### `PostComposerView`

- text
- photo
- video
- progress
- food
- goal update

### `PostDetailView`

- post
- comments
- likes
- share
- report

---

# 45. Live Screens

### `LiveDiscoveryView`

Sections:

```text
LIVE NOW
UPCOMING
RECOMMENDED
```

### `LiveRoomPreJoinView`

- host
- room title
- participants
- camera preview
- mic
- camera

### `LiveRoomView`

Controls:

```text
mute
camera
speaker
participants
chat
leave
```

### `LiveRoomHostView`

Additional:

```text
mute participant
remove participant
end room
invite speaker
```

---

# 46. Messaging Screens

### `MessagesView`

- conversations
- unread counts

### `ConversationView`

- messages
- attachments
- replies
- typing
- read state

### `NewMessageView`

- search user
- select
- create conversation

---

# 47. Coaching Screens

### `CoachDiscoveryView`

Filters:

```text
specialty
goal
price
rating
availability
language
```

### `CoachProfileView`

- profile
- specialties
- reviews
- pricing
- availability
- book

### `BookingView`

- calendar
- time
- duration
- confirmation

### `CoachSessionView`

- video
- chat
- session information

### `CoachDashboardView`

For coaches:

```text
clients
today
upcoming
messages
performance
```

### `ClientDetailView`

Tabs:

```text
Overview
Nutrition
Progress
Goals
Activity
Sessions
Notes
```

Every tab is permission-controlled.

---

# 48. Camera/Create Screens

Camera is a universal creation surface.

```text
Create
├── Food Photo
├── Progress Photo
├── Post
├── Video
├── Check-in
├── Live Room
└── Shared Film (existing Film/Foto feature — kept intact)
```

The Camera tab should not become a dead-end photo gallery.

It is a **creation and sharing entry point**.

The existing Film/Foto disposable-camera feature (films, film_members, film_shots,
film_invites + `film-shots` storage bucket) is preserved and surfaced here as
**Shared Film** — shared photo moments within groups and challenges.

---

# 49. Profile Screens

### `ProfileView`

- profile header
- transformation
- stats
- goals
- groups
- coach
- achievements

### `EditProfileView`

### `PrivacyView`

### `SubscriptionView`

### `NotificationSettingsView`

### `AISettingsView`

### `ConnectedHealthView`

### `AccountSecurityView`

---

# 50. Web Screens

## Public website

```text
/
 /features
 /ai
 /tracking
 /communities
 /live
 /coaches
 /pricing
 /about
 /help
 /privacy
 /terms
```

## Member application

```text
/app
/app/track
/app/nutrition
/app/progress
/app/goals
/app/groups
/app/groups/[slug]
/app/live
/app/messages
/app/ai
/app/profile
/app/settings
/app/billing
```

## Coach application

```text
/coach
/coach/clients
/coach/clients/[id]
/coach/nutrition
/coach/progress
/coach/sessions
/coach/calendar
/coach/messages
/coach/groups
/coach/profile
/coach/settings
```

## Admin

```text
/admin
/admin/users
/admin/groups
/admin/reports
/admin/coaches
/admin/subscriptions
/admin/ai
/admin/analytics
```

---

# 51. API Architecture

Use versioned APIs.

```text
/api/v1/
```

All APIs return:

```text
{
  data,
  error,
  meta
}
```

Errors:

```text
{
  code,
  message,
  details
}
```

---

# 52. Authentication APIs

```text
POST /api/v1/auth/profile
GET  /api/v1/me
PATCH /api/v1/me
GET /api/v1/me/entitlements
GET /api/v1/me/preferences
```

Supabase Auth handles actual authentication.

---

# 53. Nutrition APIs

```text
GET  /api/v1/nutrition/day
GET  /api/v1/nutrition/history
POST /api/v1/nutrition/food-log
PATCH /api/v1/nutrition/food-log/:id
DELETE /api/v1/nutrition/food-log/:id

POST /api/v1/ai/food-estimate
POST /api/v1/nutrition/barcode
GET  /api/v1/nutrition/foods/search
```

---

# 54. Goal APIs

```text
GET  /api/v1/goals
POST /api/v1/goals
GET  /api/v1/goals/:id
PATCH /api/v1/goals/:id
DELETE /api/v1/goals/:id

POST /api/v1/goals/:id/milestones
```

---

# 55. Progress APIs

```text
GET  /api/v1/progress
POST /api/v1/progress/weight
POST /api/v1/progress/measurement
POST /api/v1/progress/mood
POST /api/v1/progress/activity
POST /api/v1/progress/photo
GET  /api/v1/progress/trends
```

---

# 56. Group APIs

```text
GET  /api/v1/groups
POST /api/v1/groups
GET  /api/v1/groups/:id
PATCH /api/v1/groups/:id
POST /api/v1/groups/:id/join
POST /api/v1/groups/:id/leave

GET  /api/v1/groups/:id/posts
POST /api/v1/groups/:id/posts

POST /api/v1/posts/:id/comments
POST /api/v1/posts/:id/like
DELETE /api/v1/posts/:id/like
```

---

# 57. Messaging APIs

```text
GET  /api/v1/conversations
POST /api/v1/conversations
GET  /api/v1/conversations/:id/messages
POST /api/v1/conversations/:id/messages
POST /api/v1/messages/:id/read
```

Realtime delivery is handled by Supabase Realtime.

---

# 58. Live APIs

```text
GET  /api/v1/live
POST /api/v1/live
GET  /api/v1/live/:id
POST /api/v1/live/:id/join
POST /api/v1/live/:id/leave
POST /api/v1/live/:id/token
POST /api/v1/live/:id/end
```

`/token` performs authorization before generating the Agora token.

---

# 59. Coaching APIs

```text
GET  /api/v1/coaches
GET  /api/v1/coaches/:id
POST /api/v1/coaches/profile
PATCH /api/v1/coaches/profile

GET  /api/v1/coaches/availability
POST /api/v1/coaches/availability

GET  /api/v1/coaches/clients
POST /api/v1/coaches/clients/invite

GET  /api/v1/coaches/sessions
POST /api/v1/coaches/sessions
PATCH /api/v1/coaches/sessions/:id

POST /api/v1/coaches/sessions/:id/token
```

---

# 60. AI APIs

```text
POST /api/v1/ai/chat
POST /api/v1/ai/food-estimate
POST /api/v1/ai/food-verify
POST /api/v1/ai/insight
POST /api/v1/ai/progress-analysis
POST /api/v1/ai/recommendations
POST /api/v1/ai/feedback
```

All AI requests pass through the AI Gateway.

---

# 61. AI Tool Contract

Initial tools:

```text
get_user_profile
get_user_goals
get_active_goal
get_food_log
get_daily_nutrition
get_nutrition_history
get_weight_history
get_measurements
get_progress_summary
get_activity_summary
get_user_groups
get_recommended_groups
get_live_rooms
get_upcoming_sessions
get_coach_relationship
search_foods

create_food_log
update_food_log
delete_food_log
create_goal
update_goal
create_progress_entry
recommend_group
recommend_live_room
```

Tool permissions are user-scoped.

---

# 62. AI Food Pipeline

**Rule: the AI never computes final nutrition numbers.** The vision model
identifies foods and estimates portions; the deterministic Nutrition Engine
computes nutrition from the canonical database.

```text
iOS Camera
 ↓
Image compression
 ↓
Supabase private storage
 ↓
VISION MODEL (Gemini 3.7 Flash)
 ↓
Food identification
 ↓
Portion estimate ("Chicken breast ≈ 180g")
 ↓
VERALIFY NUTRITION ENGINE (deterministic)
 ↓
Canonical nutrition database lookup (foods + provenance §9)
 ↓
Deterministic calculation (grams × per-gram macros)
 ↓
Confidence score
 ↓
AI verification pass
 ↓
User confirmation
 ↓
food_logs (nutrition provenance recorded)
```

If confidence is below threshold:

```text
Gemini
 ↓
Claude Opus 5 verification
```

If disagreement remains:

```text
Ask user
```

Never silently invent precision.

---

# 63. AI Response Contract

All important AI operations use schemas.

Example:

```text
FoodEstimate {
  items: [
    {
      name: string
      quantity: number
      unit: string
      grams: number
      calories: number
      protein_g: number
      carbs_g: number
      fat_g: number
      confidence: number
      assumptions: string[]
    }
  ]
  overall_confidence: number
  requires_confirmation: boolean
}
```

---

# 64. AI Coach Contract

The AI coach may:

```text
read authorized fitness data
analyze trends
explain patterns
suggest reasonable actions
recommend communities
recommend live rooms
help users stay accountable
```

The AI coach may not:

```text
diagnose
prescribe
claim certainty
recommend dangerous dieting
encourage self-harm
pretend to be a doctor
```

## Health Safety Layer (architecture, not just prompts)

Safety is enforced as pipeline stages, not prompt instructions:

```text
User request
 ↓
Safety classifier (pre-check)
 ↓
Allowed? ──no──→ safe refusal + support resources
 ↓ yes
Domain AI
 ↓
Output validator (structured contract §63)
 ↓
Safety post-check
 ↓
User
```

The classifier must specifically detect:

```text
eating-disorder-adjacent queries
extreme calorie restriction
medication questions
medical conditions
rapid weight loss requests
body-image distress
```

Blocked/flagged requests are logged to `audit_logs` (action = ai_safety_block)
for pattern review. Post-check failures are never shown to the user.

---

# 65. AI Recommendation Architecture

Do not ask the LLM to search every user/group.

Use:

```text
Candidate generation
 ↓
Database filters
 ↓
Behavioral scoring
 ↓
AI ranking
 ↓
Recommendation
```

Example:

```text
goal = fat_loss
language = English
activity = high
community size > 20
recent activity = high
```

Then AI chooses the best candidates.

---

# 66. AI Cost Controls

Every AI request has:

```text
task
model
max_tokens
timeout
fallback
budget
```

High-volume requests use cheaper models.

High-value requests use frontier models.

Use caching for repeated context.

Do not send massive historical context unnecessarily.

---

# 67. AI Model Evaluation

Create a permanent benchmark suite.

## Food benchmark

Minimum:

```text
500+ real food images
```

Categories:

```text
restaurant
homemade
mixed dishes
drinks
desserts
international cuisines
poor lighting
partial meals
large portions
small portions
```

Metrics:

```text
food identification accuracy
portion accuracy
calorie MAE
protein MAE
macro MAE
confidence calibration
user correction rate
```

## Reasoning benchmark

Evaluate:

```text
nutrition analysis
progress analysis
goal reasoning
personalization
hallucination
safety
tool correctness
structured-output validity
```

The production model is selected by Veralify's benchmark, not by generic leaderboard position.

---

# 68. Notifications

Notification triggers:

```text
goal milestone
food streak
AI insight
live room starting
group activity
comment
like
message
coach message
booking
session reminder
subscription
```

Push:

```text
APNs
```

Backend:

```text
notification record
→ push queue
→ APNs
```

---

# 69. HealthKit

HealthKit integration should be permission-based.

Potential data:

```text
steps
active energy
workouts
weight
height
heart rate where appropriate
```

Never require HealthKit for basic app functionality.

The user explicitly chooses what Veralify can read.

---

# 70. Privacy

The system must support:

```text
private
followers/community
coach
public
```

for relevant content.

Default:

```text
health = private
nutrition = private
weight = private
progress = private
```

## Data Retention Policy Matrix (required)

Veralify handles fitness/health-related data. Retention is specification, not
an implementation detail — data deletion is already a launch criterion.

| Domain | Retention | On account deletion | Backups | Derived AI data | Anonymized analytics |
|---|---|---|---|---|---|
| Food logs | While account active | Deleted | Purged ≤ 30 days | Deleted | May survive |
| Weight / measurements | While account active | Deleted | Purged ≤ 30 days | Deleted | May survive |
| Mood entries | While account active | Deleted | Purged ≤ 30 days | Deleted | No |
| HealthKit imports | While account active | Deleted | Purged ≤ 30 days | Deleted | No |
| Progress photos/videos | While account active | Deleted (storage + rows) | Purged ≤ 30 days | Deleted | No |
| AI conversations | 12 months rolling | Deleted | Purged ≤ 30 days | Deleted | May survive |
| AI execution logs (raw prompts/outputs) | **90 days** then purged | Deleted | Purged ≤ 30 days | n/a | Aggregates only |
| Coach notes | While relationship active + 12 months | Deleted | Purged ≤ 30 days | Deleted | No |
| Messages | While account active | Deleted; peer copies anonymized | Purged ≤ 30 days | Deleted | No |
| Audit logs | 24 months (compliance) | Retained, actor pseudonymized | Standard | n/a | Yes |
| Billing records | Legal minimum (tax/accounting) | Retained as required by law | Standard | n/a | Yes |

**AI observability retention:** conversation history (product feature) is
distinct from AI execution logs (debugging). Raw prompts may contain sensitive
health information and must not be stored indefinitely — 90-day purge is
mandatory; long-term AI quality analysis uses aggregated/anonymized metrics
only.

---

# 71. Security Requirements

Mandatory:

```text
RLS on exposed tables
server-only secrets
signed media URLs
Agora token authorization
Stripe webhook signature verification
AI rate limits
API rate limits
upload limits
content moderation
block/report functionality
audit logs
idempotency
```

Never expose:

```text
OPENROUTER_API_KEY
STRIPE_SECRET_KEY
AGORA_APP_CERTIFICATE
SUPABASE_SERVICE_ROLE_KEY
RESEND_API_KEY
```

to iOS or browser clients.

---

# 72. Repository Architecture

Current repository layout (this repo):

```text
veralify/
├── src/                      # Next.js 15 web app (App Router)
│   ├── app/                  # routes: api, auth, dashboard, pricing, ...
│   ├── components/
│   ├── emails/               # React Email templates (Resend)
│   ├── lib/
│   └── i18n/
│
├── veralify-App/
│   ├── iOS/veralify/         # SwiftUI app (Xcode project)
│   │   └── veralify/
│   │       ├── Core/         # AI, Camera, Config, Film, Network, ...
│   │       ├── Features/     # Auth, Chat, Films, Profile, ...
│   │       └── Models/
│   └── macOS/
│
├── supabase/
│   ├── migrations/
│   └── functions/            # Edge Functions (agora-token, ai gateway, ...)
│
├── design-system/
├── docs/                     # this spec, backend plan, legal
├── scripts/
├── public/
└── .github/workflows/
```

Target evolution (optional, post-launch): extract shared `packages/`
(api-contracts, validation, types) if web/iOS contract drift becomes a problem.
Do not restructure into a monorepo before Phase 13.

---

# 73. AI Coding Agent Lineup

Do not use one AI coding agent for everything.

## Architect

**Claude Opus 5**

Responsibilities:

- architecture
- database review
- RLS
- API design
- complex refactors
- security review

Claude Opus 5 is currently positioned by OpenRouter for demanding reasoning, coding, long-horizon agentic work and code review.

## Primary implementation agent

**GPT-5.6 Sol Pro**

Responsibilities:

- difficult implementation
- backend
- complex Swift
- architecture-sensitive changes
- multi-file implementation

GPT-5.6 Sol Pro currently supports tool calling and structured outputs and is specifically the higher-reasoning configuration of GPT-5.6 Sol.

## Fast implementation agent

**Gemini 3.7 Flash**

Responsibilities:

- straightforward components
- UI
- tests
- small refactors
- documentation
- repetitive implementation

## Parallel/cheap agent

**MiMo-V2.5-Pro**

Responsibilities:

- secondary implementation
- test generation
- code search
- background tasks
- alternative implementation proposals

---

# 74. Agent Ownership

## Agent A — Architecture

Owns:

```text
docs/architecture
docs/database
docs/security
```

Cannot modify application code without approval.

## Agent B — Backend

Owns:

```text
supabase/            (migrations, seed)
src/lib/api/         (API contracts & server logic)
```

## Agent C — AI

Owns:

```text
supabase/functions/  (ai-gateway, food-scan, insights, agora-token)
src/lib/ai/
```

## Agent D — iOS

Owns:

```text
veralify-App/
```

## Agent E — Web

Owns:

```text
src/                 (Next.js app — pages, components, emails)
```

Paths match the **current repository layout** (§72). If the repo later evolves
into a monorepo (post-Phase-13), remap ownership in the same PR that moves the
code — ownership must never reference directories that do not exist.

## Agent F — QA/Security

Can inspect everything.

Cannot make architectural changes without an issue/approval.

---

# 75. Implementation Order — Parallel Workstreams

The build is **not sequential**. After the contracts are frozen
(schema + RLS matrix + API contracts + AI tool contract + entitlement keys),
workstreams run in parallel:

```text
               ARCHITECTURE (contracts frozen)
                    │
          ┌─────────┼──────────┐
          ↓         ↓          ↓
       Backend      AI        Design
     (DB, RLS,   (gateway,   (design
      auth,       food        system,
      billing)    pipeline,   screens)
          │       insights)     │
          └────┬────┴──────┬───┘
               ↓           ↓
             iOS          Web
               │           │
               └─────┬─────┘
                     ↓
               Integration
                     ↓
              Security / QA
                     ↓
                  Launch
```

Phases 1–13 below define scope and acceptance per workstream — they are
dependency groups, not a strict serial order. A workstream may start as soon as
the contracts it consumes are frozen.

## Phase 0 — Repository

```text
1. Use existing repo (web at root, iOS in veralify-App/) — no monorepo restructure
2. CI/CD
3. environments
4. secrets
5. linting (Biome — existing)
6. formatting (Biome — existing)
7. testing
8. type generation (supabase gen types)
```

No product features yet.

---

# 76. Phase 1 — Database Foundation

Order:

```text
1. profiles
2. preferences
3. privacy
4. goals
5. nutrition
6. progress
7. groups
8. social
9. messaging
10. live rooms
11. coaching
12. subscriptions
13. AI tables
14. notifications
15. moderation
```

After every domain:

```text
migration
→ indexes
→ RLS
→ seed data
→ tests
```

---

# 77. Phase 2 — Auth

Build:

```text
email
Apple
Google where appropriate
password recovery
email verification
session management
profile creation
onboarding
```

Authentication must be complete before social functionality.

---

# 78. Phase 3 — Entitlements

Build **both commerce rails** before premium features.

Order:

```text
Stripe products + StoreKit products (mirrored)
→ features
→ product-feature mapping
→ Stripe checkout (web) + StoreKit purchase flow (iOS)
→ Stripe webhook + Apple App Store Server Notifications
→ local subscription + iap_transactions
→ normalized user_entitlements (source: apple | stripe)
→ entitlement middleware (server) + entitlement client state
```

Do not build Pro-only screens before entitlement infrastructure works.
Never bill iOS digital features through Stripe (§34).

---

# 79. Phase 4 — AI Gateway

Build:

```text
OpenRouter client
→ model registry
→ routing
→ structured outputs
→ tools
→ logging
→ cost tracking
→ fallback
→ rate limits
```

Then implement food AI.

---

# 80. Phase 5 — Nutrition

Order:

```text
food database
→ food search
→ manual logging
→ barcode
→ photo upload
→ AI estimate
→ confirmation
→ daily summary
→ AI insight
```

---

# 81. Phase 6 — Progress

Order:

```text
goals
→ weight
→ measurements
→ mood
→ activity
→ photos
→ trends
→ milestones
→ AI analysis
```

---

# 82. Phase 7 — Social

Order:

```text
groups
→ membership
→ feed
→ posts
→ comments
→ likes
→ bookmarks
→ moderation
```

---

# 83. Phase 8 — Chat

Order:

```text
conversations
→ membership
→ messages
→ realtime
→ unread counts
→ attachments
→ moderation
→ notifications
```

---

# 84. Phase 9 — Agora

Order:

```text
live_rooms
→ room creation
→ authorization
→ token generation
→ prejoin
→ RTC
→ participants
→ host controls
→ chat integration
→ session completion
```

---

# 85. Phase 10 — Coaching

Order:

```text
coach profiles
→ verification
→ discovery
→ client relationships
→ permissions
→ availability
→ bookings
→ sessions
→ Agora
→ notes
→ reviews
```

---

# 86. Phase 11 — iOS

Build in this order (entitlements early — premium gating affects AI usage,
groups, progress, analytics, coaching and live features; it must not be bolted
on at the end):

```text
1. App shell
2. Auth
3. Entitlements + StoreKit subscription layer
4. Onboarding
5. Home
6. Track
7. Food
8. AI food camera
9. Goals
10. Progress
11. Connect
12. Groups
13. Posts
14. Chat
15. Live
16. Coaching
17. Camera/Create
18. Profile
19. Notifications
20. HealthKit
```

---

# 87. Phase 12 — Web

Build:

```text
1. Marketing
2. Auth
3. Member dashboard
4. Nutrition
5. Progress
6. Groups
7. Chat
8. Live
9. AI
10. Billing
11. Coach dashboard
12. Scheduling
13. Admin
```

---

# 88. Phase 13 — Production Hardening

Mandatory before public launch:

```text
RLS penetration testing
Storage security testing
Stripe webhook testing
Agora token testing
AI prompt-injection testing
API rate-limit testing
Load testing
Offline testing
Accessibility
App Store compliance
Privacy/legal review
Crash testing
Backup/restore testing
```

---

# 89. AI Coding Agent Prompt Contract

Every coding agent receives:

```text
You are working on Veralify.

You MUST read:
- Master Technical Specification
- architecture docs
- database docs
- security docs
- relevant API contract

You MUST:
- preserve existing architecture
- preserve RLS
- use typed APIs
- write tests
- handle loading/error/empty states
- never expose secrets
- never bypass authorization
- never invent database columns
- never hard-code AI model IDs in feature code
- never modify unrelated domains

Before changing architecture:
STOP and propose the change.
```

---

# 90. Feature Definition of Done

A feature is complete only when:

```text
implementation
+
unit tests
+
integration tests
+
RLS tests
+
permission tests
+
loading state
+
empty state
+
error state
+
offline behavior where relevant
+
analytics
+
logging
+
accessibility
+
documentation
```

---

# 91. Critical Performance Requirements

## iOS

Target:

```text
cold launch < 2 sec on modern device
cached dashboard immediately visible
image compression before upload
progressive AI response
paginated feeds
paginated chat
```

## Web

Use:

```text
server rendering
streaming where useful
image optimization
route-level caching
pagination
lazy loading
```

## Backend

Never allow:

```text
unbounded queries
unbounded feeds
unbounded message history
large synchronous AI workflows
```

---

# 92. Observability

Every request should have:

```text
request_id
user_id
route
latency
status
error
```

AI additionally:

```text
model
provider
tokens
cost
latency
fallback
task
```

Agora:

```text
room_id
user_id
join
leave
duration
quality metrics where available
```

Stripe:

```text
event_id
customer_id
subscription_id
processing status
```

---

# 93. Core Product Metrics

## Activation

```text
signup
→ onboarding
→ first food log
→ first goal
→ first group
```

## Retention

```text
D1
D7
D30
```

## AI

```text
food estimate acceptance
food correction rate
AI helpfulness
AI latency
AI cost/user
```

## Community

```text
groups joined
posts/user
comments/user
messages/user
live rooms attended
live attendance duration
```

## Coaching

```text
coach profile views
booking conversion
session completion
repeat bookings
```

## Business

```text
Free → Pro
Free → Coach
monthly recurring revenue
annual recurring revenue
churn
ARPU
AI cost as % revenue
```

---

# 94. Launch Criteria

Veralify is ready for production when:

```text
Auth stable
RLS audited
Food AI benchmarked
AI fallback tested
Stripe tested
Agora token system tested
Notifications working
Crash monitoring enabled
Analytics enabled
Moderation functional
Privacy controls functional
Data deletion functional
Backup/restore tested
```

---

# 95. Final Architecture

```text
                         VERALIFY
                Track. Connect. Transform.
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
      TRACK                 CONNECT               COACH
        │                     │                     │
    Nutrition              Groups                Clients
    Food AI                Posts                 Sessions
    Goals                  Chat                  Scheduling
    Progress               Live                  Video
    Health                 Community             Data
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                         VERALIFY AI
                              │
              ┌───────────────┼────────────────┐
              │               │                │
          Multimodal       Reasoning          Fast
              │               │                │
        Gemini 3.7       GPT-5.6 Sol Pro   Gemini 3.6
              │         Claude Opus 5          │
              │               │                │
              └───────────────┼────────────────┘
                              │
                         OpenRouter
                              │
                     AI Tool Gateway
                              │
              ┌───────────────┼───────────────┐
              ↓               ↓               ↓
          Supabase          Agora           Stripe
          Postgres           RTC           Billing
          Auth
          Storage
          Realtime
          Edge Functions
              │
        ┌─────┴─────┐
        ↓           ↓
       iOS         Web
```

# 96. Final Technology Decisions

**KEEP**

```text
Swift / SwiftUI
Next.js 15+
Supabase
Stripe
Resend
Vercel
```

**ADD**

```text
OpenRouter
Agora RTC
StoreKit 2 (iOS digital subscriptions)
Stripe Connect (coach marketplace)
Sentry
PostHog
pgvector
```

**USE OPENROUTER MODELS**

```text
Primary reasoning:
openai/gpt-5.6-sol-pro

Reasoning fallback / verification:
anthropic/claude-opus-5

Primary multimodal:
google/gemini-3.7-flash

Fast general:
google/gemini-3.6-flash

Low-cost multimodal:
xiaomi/mimo-v2.5

Low-cost coding/agent:
xiaomi/mimo-v2.5-pro
```

**DO NOT**

```text
train a foundation model
hard-code one AI provider
hard-code one AI model
use Agora as the application database
allow AI direct SQL access
bypass RLS
trust client-side subscription state
sell iOS digital features through Stripe (IAP required)
let AI compute final nutrition numbers (nutrition engine does)
expose secrets
make progress/health data public by default
```

**THE MOST IMPORTANT ARCHITECTURAL RULE**

```text
Veralify owns the product.

OpenRouter supplies intelligence.
Supabase owns application state.
Agora owns real-time media.
Stripe owns billing.
```

This specification is the canonical contract for all subsequent Veralify implementation work. Any AI coding agent or human engineer should treat changes to the database model, authorization model, AI gateway, entitlement model, or third-party integration boundaries as architecture changes requiring review rather than silently modifying them.