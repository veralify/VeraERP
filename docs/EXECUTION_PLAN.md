# Veralify — Execution Plan to First Revenue

**Created:** 2026-09-18
**Goal:** A real coach is paid for a real session booked through Veralify, with the platform fee collected.
**Focus:** Coaching marketplace only. Everything else is parked.
**Mode:** Solo + Claude Code agents running parallel workstreams.
**Companion docs:** `AUDIT_2026-09-18.md` (why), `AGENT_BRIEFS.md` (how).

---

## The one metric

**Time to first paid booking by a coach and client neither of whom is you.**

Nothing in this plan exists for any other reason. If a task does not move that number, it is not in this plan.

A useful intermediate: **time to first paid booking in Stripe test mode**, which is M1 and should land inside two weeks.

---

## Parked — explicitly not doing

Write these down so they stop pulling at you. They are not cancelled; they are *after first revenue*.

| Parked | Why |
|---|---|
| iOS app | Web-only proves the marketplace. An App Store review cycle cannot be inside your critical path. |
| AI food tracking / OpenRouter | Consumer Pro is revenue stream 3. It shares no code path with getting a coach paid. |
| Communities, live rooms, messaging | Retention features for a product with no users yet. |
| Coach SaaS tiers (€19–99) | Sell tools to coaches *after* you have proven you can bring them clients. Right now it is the gate blocking them. |
| `money-manager-web-mvp-v1` | Unrelated product living in this repo. Move it to its own repo in M0. |
| Phases 13–19 of the pivot plan | Downstream of a working marketplace. |

Move `docs/SPRINT_TASKS.md` to `docs/archive/` in M0 — it describes the eSIM business and actively misleads any agent that reads it.

---

## Milestones

Weeks are calendar weeks at agent-heavy pace. Each milestone has a single binary exit test.

### M0 — Unblock the marketplace · Week 1

*Nothing can be tested until these are done. Do them first, in this order.*

| # | Task | Exit condition |
|---|---|---|
| 0.1 | Remove the `coach_discovery` / `VERALIFY_PRO` gate from `/coaches` | A signed-out visitor sees the coach listing |
| 0.2 | Replace the `VERALIFY_COACH` gate on coach onboarding with an invite/allowlist model | A coach with no subscription can create a profile and start Connect onboarding |
| 0.3 | Create Stripe account, enable Connect, put test keys in `.env` and Vercel | `getStripe()` returns a live client; `/api/stripe/connect/onboarding` reaches Stripe |
| 0.4 | Push all 38 migrations to the hosted Supabase project | Remote schema matches local; RLS tests pass against remote |
| 0.5 | Deploy to Vercel with env validation green | `pnpm validate:env` passes in CI; production URL loads |
| 0.6 | Repo hygiene — archive `SPRINT_TASKS.md`, extract money-manager, prune dead branches | `git branch` shows main + active feature branches only |

**Exit test:** a coach account with no entitlements can publish a bookable session slot, and a signed-out visitor can see it.

---

### M1 — First paid booking, test mode · Week 2

*The whole payment rail, exercised once, end to end.*

| # | Task | Exit condition |
|---|---|---|
| 1.1 | Run Connect Express onboarding to completion with a test coach | `coach_stripe_accounts.charges_enabled = true` |
| 1.2 | Book and pay with test card `4242…` | Stripe Checkout completes, redirects to billing |
| 1.3 | Verify webhook end to end | `session_bookings.status = 'confirmed'`, platform fee recorded, ledger row written |
| 1.4 | Fix whatever breaks | *Assume this takes longer than 1.1–1.3 combined.* |
| 1.5 | Booking confirmation emails — client and coach | Both parties receive an email with session time and join link within 60s |

**Exit test:** €50 test session → booking confirmed → €7.50 platform fee recorded → both parties emailed. Zero manual steps.

> **Sequencing note:** 1.4 is not padding. This is the first time any of this code touches a real Stripe account. Budget for Connect capability requirements, currency minimums, and webhook signature issues.

---

### M2 — Deliver the session · Week 3

*You must not take live money before this milestone closes.*

Do the interim first — it unblocks revenue in an afternoon. Agora is a week of work for a better experience you have not yet earned.

| # | Task | Exit condition |
|---|---|---|
| 2.1 | **Interim:** add `meeting_url` to `coach_sessions`; coach pastes their own Zoom/Meet link | Confirmed booking shows a working join link to both parties |
| 2.2 | Session detail page for client and coach | Both can see time, duration, join link, cancel option |
| 2.3 | Reminder email 24h and 1h before | Reminders fire from the existing `notification_jobs` outbox + worker |
| 2.4 | *Deferred:* wire `agora-token` function to a web join page | Only after 10+ real sessions have run on 2.1 |

**Exit test:** a booked session can be attended by both parties without either contacting you.

---

### M3 — Trust and operations · Week 4

*The things that turn one transaction into a business.*

| # | Task | Exit condition |
|---|---|---|
| 3.1 | Cancellation flow with policy (suggested: free >24h, 50% inside 24h, no refund for no-show) | Client can cancel; refund issued via Stripe; slot released |
| 3.2 | Coach earnings page | Coach sees pending, paid out, and platform fee per session |
| 3.3 | Post-session review → `coach_reviews` | Rating and review count on the coach card are real, not zeros |
| 3.4 | Update Terms of Service for marketplace + Connect | Published; references platform fee, cancellation policy, coach-as-independent-contractor |
| 3.5 | Sentry + PostHog wired | You learn about errors before a coach emails you |

**Exit test:** a client cancels a session and is refunded correctly with no manual intervention.

---

### M4 — Go live · Week 5

*Stop building. Start recruiting.*

| # | Task | Exit condition |
|---|---|---|
| 4.1 | **Verify legal entity status** (see audit §7) | Confirmed active and able to operate as a Stripe Connect platform |
| 4.2 | Switch to Stripe live keys; live webhook endpoint | Live-mode test booking with a real card succeeds |
| 4.3 | Recruit 5–10 founding coaches by hand | Profiles live with real photos, rates, availability |
| 4.4 | Founding-coach offer: 0% platform fee for first 90 days | Written into `platformFee` config, not hardcoded |
| 4.5 | Drive the waitlist to the live marketplace | First real booking |

**Exit test:** the metric. A real coach paid by a real client.

> **On 4.3:** this is the hardest task in the plan and the one an agent cannot do. Ten coaches recruited personally beats any amount of code. Start conversations during M1 — do not wait for M4.

> **On 4.4:** waiving the fee costs nothing when volume is zero and removes the only objection a founding coach has. Charge once you are demonstrably sending them clients.

---

### M5 — Learn · Week 6+

Ten real bookings will tell you more than the 50,000-word specification did. Only after that decide whether the next thing is Agora video, Coach SaaS tiers, iOS, or consumer Pro.

Re-read `PIVOT_PLAN.md` at this point and delete what the market did not ask for.

---

## Dependency graph

```
M0.1 ─┬─> M1.1 ──> M1.2 ──> M1.3 ──> M1.4 ──> M1.5 ─┐
M0.2 ─┤                                              │
M0.3 ─┤                                              ├──> M2.1 ──> M2.2 ──> M2.3
M0.4 ─┤                                              │              │
M0.5 ─┘                                              │              v
                                                     └────────> M3.1 ─> M3.2 ─> M3.3
M0.6 (independent, do anytime)                                        │
                                                                      v
M4.1 (start now — external dependency, may take weeks) ──────────> M4.2 ─> M4.5
M4.3 (start during M1 — human work, runs in parallel) ───────────────┘
```

Two things start **today** despite living in M4: the legal entity check (4.1) and coach recruitment conversations (4.3). Both have long external lead times and neither depends on code.

---

## How to run this with agents

Four workstreams can run in parallel after M0. See `AGENT_BRIEFS.md` for paste-ready prompts.

| Agent | Owns | Starts |
|---|---|---|
| **A — Access** | Entitlement gate removal, invite model, auth surface | M0, immediately |
| **B — Payments** | Stripe config, Connect, webhook verification, refunds | M0.3, then M1, M3.1 |
| **C — Sessions** | Meeting links, session pages, reminders, Agora later | after M0 |
| **D — Comms** | Booking emails, reminders, review requests | after M0 |

Rules that keep parallel agents from colliding:

1. **One agent per directory tree.** A owns `src/app/coaches` + gates; B owns `src/app/api/stripe`; C owns `src/app/dashboard/coach` + session pages; D owns `src/emails`.
2. **Migrations are serialized.** Only one agent writes to `supabase/migrations/` at a time — timestamp collisions are silent and painful.
3. **Every brief ends with `pnpm check`.** Type errors caught by the agent cost nothing; type errors caught by you cost a context switch.
4. **No agent edits `PIVOT_PLAN.md`.** The spec is frozen; this plan supersedes it for execution order.

---

## What "done" looks like, honestly

At the end of M4 you will have a marketplace with ten coaches, a handful of bookings, and no AI, no communities, no iOS app, and no live video. That is not a smaller version of the vision in `PIVOT_PLAN.md` — it is the only version of it that can be funded by its own revenue.

The 19-phase spec is a good map of where this goes. It is a bad description of what to build next.
