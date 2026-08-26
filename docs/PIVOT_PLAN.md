# Veralify Pivot Plan

> **The social fitness app that combines AI-powered tracking with real human accountability.**

Track your transformation, then experience it with people going through the same journey.

Inspiration — not imitation:
- **Cal AI** → effortless food / nutrition / progress tracking
- **Clubhouse** → drop into a live conversation around a shared, *measurable* goal
- **Veralify's own** → the existing Film/Foto feature becomes shared moments inside the journey

---

## 1. The Core Loop

```
        TRACK
          ↓
      AI understands
       your progress
          ↓
       DISCOVER
          ↓
    Join your community
          ↓
       CONNECT
          ↓
 Live rooms / group check-ins
          ↓
       GET SUPPORT
          ↓
       STAY ACCOUNTABLE
          ↓
        TRACK
```

The product loop in practice:

> Lose 10kg → join community → track meals → AI sees patterns → attend weekly
> accountability room → meet people with the same goal → share progress → coach
> answers questions → repeat.

The magic combination: **AI → insight → community → accountability.**

Example:

> **User:** "I've been eating well all week but I'm not losing weight."
>
> **Veralify:** "Looking at your last 14 days, your average intake is close to
> your target, but your weekend intake is ~22% higher than weekdays. Your weight
> trend is still moving down, just more slowly than your target."
>
> *Want to discuss it with the community? → Join: Weekend Accountability*

---

## 2. Tech Stack

### Current (preserved)

| Layer | Technology |
|-------|-----------|
| iOS App | Swift / SwiftUI, Supabase SDK, StoreKit 2 |
| Website | Next.js 15, React 19, Tailwind CSS 4, Vercel |
| Backend | Supabase (Postgres + Auth + Storage + Realtime + Edge Functions) |
| Payments | Stripe (web) + StoreKit (iOS) |
| Email | Resend + React Email |
| Tooling | pnpm, Biome, TypeScript |

### New

| Capability | Technology |
|-----------|-----------|
| Live audio rooms, video sessions | Agora RTC (iOS: AgoraRtcKit · Web: agora-rtc-sdk-ng) |
| Group chat / typing indicators | Agora RTM + Supabase persistence |
| Food photo recognition, meal parsing, insights | Vision + LLM provider via Supabase Edge Functions |

---

## 3. Backend Architecture — Six Domains

```
VERALIFY
│
├── IDENTITY
│   ├── Users
│   ├── Profiles
│   └── Subscriptions
│
├── TRACKING
│   ├── Food
│   ├── Nutrition
│   ├── Goals
│   ├── Weight
│   ├── Measurements
│   └── Progress
│
├── AI
│   ├── Food recognition
│   ├── Nutrition estimation
│   ├── Insights
│   ├── Recommendations
│   └── Personalization
│
├── COMMUNITY
│   ├── Groups
│   ├── Posts
│   ├── Comments
│   ├── Messaging
│   └── Live rooms
│
├── COACHING
│   ├── Coaches
│   ├── Clients
│   ├── Bookings
│   └── Sessions
│
└── PAYMENTS
    ├── Plans
    ├── Entitlements
    └── Stripe
```

---

## 4. iOS App Experience

### Tab bar

```
┌────────┬────────┬────────┬─────────┬─────────┐
│  Home  │ Track  │   ＋   │ Connect │ Profile │
└────────┴────────┴────────┴─────────┴─────────┘
```

Camera is **no longer a primary tab** — it becomes the global ＋ creation button.

### 🏠 Home — AI fitness command center
- Calories / macros rings
- Today's progress — *"You're 320 kcal away from today's target"*
- AI insight card (with CTA → join room / join group)
- Streak
- Group activity
- LIVE NOW rail + upcoming live rooms
- Coach recommendations

### ✨ Track — Cal AI-style logging
Logging a meal should take **seconds, not minutes**:
1. **Photo** → AI identifies the meal
2. **Barcode** → nutrition lookup
3. **Search** → food database
4. **Natural language** → *"I had 2 eggs, toast and an avocado"*

AI estimates calories/macros → user confirms → daily rings update.

### 🎙️ Connect — the social layer

```
LIVE NOW
🎙️ Fat Loss Accountability        👥 84
🎙️ Morning Workout Check-in       👥 31
🎙️ Ask a Nutrition Coach          👥 126
🎙️ Beginners Starting Their Journey 👥 47
```

Tap → enter live room (Agora RTC). Plus: group discovery by goal type, group
feeds (posts, progress updates, transformations), group chat, people discovery
("same goal as you").

### ＋ Create button (everywhere)
- Log food (photo / barcode / text)
- Take progress photo
- Share transformation
- Start post
- Start / schedule live room
- **Shared Film** (existing Film/Foto feature, kept intact)

### 👤 Profile — transformation showcase
- Transformation timeline (before/after progress photos)
- Goals, stats, weight chart
- Achievements & streak
- Groups
- Subscription
- Coach section

---

## 5. Website

The website is **not the iOS app in a browser** — it is the discovery +
conversion + deeper dashboard layer.

### Public site
> *"Your fitness journey, with people beside you."*

Demonstrate in order:
1. **AI TRACKING** — Take a photo of your meal.
2. **COMMUNITY** — Find people with the same goal.
3. **LIVE** — Join a room. Talk to a coach. Check in.
4. **TRANSFORMATION** — See your progress over time.

Then: **Download Veralify** + pricing.

### Logged-in member dashboard (Pro value)

```
┌──────────────────────────────────────────┐
│ Good morning, Alex                       │
│                                          │
│ Today's progress                         │
│ Calories       Protein       Water       │
│ 1,420/2,100     92/150g      1.8/2.5L    │
├──────────────────────────────────────────┤
│ AI INSIGHT                               │
│ You're consistently hitting calories,    │
│ but protein is 18% below your target.    │
├──────────────────────────────────────────┤
│ LIVE NOW                                 │
│ 🎙️ Evening Accountability                │
│ 🎙️ Nutrition Q&A                         │
├──────────────────────────────────────────┤
│ YOUR GROUPS                              │
│ Fat Loss · 2 new posts                   │
│ Beginner Strength · 5 new posts          │
└──────────────────────────────────────────┘
```

### Coach portal (Coach value)
Client roster · per-client nutrition & progress dashboards · session calendar ·
booking management · browser video sessions.

---

## 6. Pricing

| | **Free** | **Pro** | **Coach** |
|---|---|---|---|
| Tagline | Start your journey | Transform faster | Build your coaching business |
| AI food tracking | Basic | Unlimited | Unlimited |
| Nutrition dashboard | Basic | Advanced insights | Advanced insights |
| Communities | 1 | Unlimited | Unlimited |
| Progress tracking | Basic | Advanced analytics + photos | Advanced |
| Live rooms | Join | Join + premium experiences | Host group sessions |
| AI recommendations | — | ✓ | ✓ |
| Client management | — | — | ✓ (dashboards, data, scheduling) |
| Video sessions | — | — | ✓ |
| Coach profile | — | — | ✓ |

Later: paid coaching marketplace.

---

## 7. Implementation Plan

### Phase 1 — Foundation (all parallel)

| ID | Task | Notes |
|----|------|-------|
| `db-identity` | IDENTITY domain | profiles (username, avatar, bio, height, activity level, dietary pref, streak), profile_follows, subscriptions + entitlements, RLS |
| `db-tracking` | TRACKING domain | food_items, food_log (source: photo/barcode/search/natural_language), daily_summaries (incl. water), user_goals, weight_entries, body_measurements, progress_photos |
| `ai-layer` | AI domain | Edge Functions: `food-scan`, `parse-meal`, `insights-engine` (nightly 14-day pattern analysis), recommendations. Tables: ai_food_scans, ai_insights (with `cta_type → join_room/join_group`), ai_conversations |
| `db-community` | COMMUNITY domain | fitness_groups, group_members, group_posts, comments, likes, group_messages, **live_rooms** (scheduled/live/ended), room_participants (host/speaker/listener, raised_hand) |
| `db-coaching` | COACHING domain | coach_profiles, coach_clients (`data_access_granted` gates RLS reads of client data), bookings, sessions, reviews |
| `payments-entitlements` | PAYMENTS domain | Stripe Free/Pro/Coach + webhook → subscriptions; entitlement checks server & client; generalize iOS FilmPurchaseManager → SubscriptionManager |
| `agora-live` | Agora RTC/RTM | `agora-token` Edge Function (channel = live_room id, role from participants), voice-first rooms, optional video for coach sessions, Supabase Realtime for participant/raise-hand sync |

### Phase 2 — iOS

| ID | Task | Depends on |
|----|------|-----------|
| `ios-track` | Track tab: photo/barcode/search/natural-language logging, confirm sheet, daily rings | db-tracking, ai-layer |
| `ios-home` | Home tab: rings, streak, AI insight card, LIVE NOW rail, coach recs | ai-layer, db-community |
| `ios-connect` | Connect tab: LIVE NOW, room discovery, groups + feeds, chat | db-community, agora-live |
| `ios-live-room` | Room UI: speaker grid, raise hand, host controls, floating room pill | agora-live, db-community |
| `ios-coaching` | Find coach, book, 1:1 video, coach dashboard | db-coaching, agora-live, payments |
| `ios-profile` | Transformation timeline, stats, achievements, subscription | db-identity, db-tracking |
| `ios-plus-create` | Remove Camera tab → global ＋; Film feature preserved under ＋ | ios-track |
| `ios-onboarding` | Goal wizard → TDEE + macro targets → suggest 3 communities + next room | db-identity, db-tracking, db-community |

### Phase 3 — Web

| ID | Task | Depends on |
|----|------|-----------|
| `web-landing` | Public site: 4 demo sections, download CTA, new pricing | — |
| `web-member-dashboard` | /dashboard: progress bars, AI insight, LIVE NOW (join in browser), groups | ai-layer, agora-live |
| `web-coach-portal` | /dashboard/coach: clients, dashboards, scheduling, video | db-coaching, payments |

### Kept as-is ✅
**Film/Foto feature** — disposable camera films, preserved intact, reachable via ＋ → "Shared Film".

---

## 8. Strategic Positioning

Don't literally copy Clubhouse. Its most valuable idea for Veralify isn't
"audio rooms" — it's:

> **People can drop into a live conversation around a shared interest.**

Veralify's version is stronger because the shared interest is a **measurable goal**.

Position as:

> **The social fitness app that combines AI-powered tracking with real human accountability.**

Not "Cal AI + Clubhouse" — that describes the inspiration.
The former describes **why someone should actually use Veralify**.
