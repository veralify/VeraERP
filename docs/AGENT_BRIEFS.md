# Veralify — Agent-Ready Task Briefs

**Created:** 2026-09-18
**Usage:** Each brief is self-contained. Paste one into a fresh Claude Code / Cursor session at the repo root. Do not paste two at once.
**Order:** Respect the dependency graph in `EXECUTION_PLAN.md`. M0 briefs first.

**Global rules for every agent — include these if your tool drops context:**

> Repo root is `~/veralify`. Stack: Next.js 15 App Router, React 19, TypeScript, Tailwind 4, Supabase (SSR client + service-role admin client), Stripe, Biome.
> Path aliases: `@lib/*` → `src/lib/*`, `@components/*` → `src/components/*`.
> Finish every task with `pnpm check` (Biome + `tsc --noEmit`) and fix everything it reports.
> Do not edit `docs/PIVOT_PLAN.md` — it is frozen.
> Do not create new migrations unless the brief says to. If it does, use a timestamp later than `20260901090001`.
> Do not add new dependencies without saying why in your summary.

---

## M0.1 — Open coach discovery to the public

**Agent A · Owns `src/app/coaches/`**

```
Open the coach discovery page to unauthenticated visitors.

File: src/app/coaches/page.tsx

Currently the page computes:
  const canDiscover = hasEntitlement(entitlements, 'coach_discovery')
                   || hasEntitlement(entitlements, 'VERALIFY_PRO');
and renders a "Coach discovery is included with Pro" lock screen when false.

The marketplace cannot acquire clients if browsing requires a paid subscription.
Remove the gate entirely:

1. Delete the canDiscover check and the entire locked-state return branch.
2. Remove the now-unused getUserEntitlements / hasEntitlement imports if nothing
   else in the file uses them.
3. Keep the supabase.auth.getUser() call only if user identity is still needed
   for rendering; otherwise remove it too.
4. The coach listing query must work for anonymous visitors. Verify the RLS
   policy on coach_profiles allows anon SELECT of published profiles. If it does
   NOT, create a migration adding a policy that grants anon/authenticated SELECT
   on coach_profiles rows only — never on client data, bookings, or session_notes.
5. Do the same for src/app/coaches/[id]/page.tsx if it carries a similar gate.
6. Booking still requires auth. A signed-out visitor clicking "Book" should be
   sent to sign-in and returned to the coach page afterward.
7. Update the page metadata description — it currently references entitlement gating.

Acceptance criteria:
- [ ] A signed-out visitor at /coaches sees real coach cards
- [ ] A signed-out visitor at /coaches/[id] sees the full profile
- [ ] Clicking Book while signed out routes to auth, then back to the coach
- [ ] No client PII, bookings, or notes are readable by anon (verify the RLS policy text)
- [ ] pnpm check passes
```

---

## M0.2 — Replace the coach paywall with an invite allowlist

**Agent A · Owns `src/app/dashboard/coach/`, `src/app/api/stripe/connect/`**

```
Coaches currently must hold the VERALIFY_COACH entitlement (a paid subscription)
before they can create a profile or start Stripe Connect onboarding. This
deadlocks marketplace bootstrap — no coach pays to join a marketplace with no
clients. Replace the paid gate with an invite allowlist so founding coaches can
be admitted for free.

Files:
  src/app/dashboard/coach/actions.ts      (currentCoach() gate)
  src/app/dashboard/coach/page.tsx        (gate + UI messaging)
  src/app/api/stripe/connect/onboarding/route.ts  (403 on missing entitlement)

1. Create a migration adding table public.coach_invites:
     id           uuid primary key default gen_random_uuid()
     email        citext not null unique
     invited_by   uuid references auth.users(id)
     claimed_by   uuid references auth.users(id)
     claimed_at   timestamptz
     created_at   timestamptz not null default now()
   Enable RLS. Service role: full access. Authenticated users: SELECT only rows
   matching their own email (so the app can check "am I invited"). No public access.

2. Add src/lib/api/coachAccess.ts exporting:
     export async function canActAsCoach(userId: string, email: string | null): Promise<boolean>
   Returns true when ANY of:
     - an existing coach_profiles row for that user id, OR
     - an unclaimed or self-claimed coach_invites row matching the email, OR
     - the VERALIFY_COACH entitlement is held (keep this — paid coaches still qualify)

3. Replace every VERALIFY_COACH check in the three files above with canActAsCoach.
   When it returns false, show a "Coaching is invite-only during our founding
   cohort — request an invite" state instead of a billing upsell. Do not send
   rejected coaches to /pricing.

4. When a coach with a matching invite first creates their profile, stamp
   claimed_by and claimed_at on that invite row.

5. Keep the coach_profiles existence check in the Connect onboarding route — a
   coach still needs a profile before connecting a payout account.

Acceptance criteria:
- [ ] A user whose email is in coach_invites, holding no entitlements, can create
      a coach profile and reach Stripe Connect onboarding
- [ ] A user with neither invite, profile, nor entitlement sees the invite-request
      state and cannot create a profile
- [ ] An existing coach with a profile is never locked out
- [ ] Invites are claimed exactly once
- [ ] RLS blocks users from reading invites for other emails
- [ ] pnpm check passes
```

---

## M0.6 — Repo hygiene

**Any agent · Do this while M0.1/M0.2 are in review**

```
Reduce repo noise so future agents read only current context.

1. Create docs/archive/ and move docs/SPRINT_TASKS.md into it. That file describes
   the abandoned eSIM business and misleads any agent that reads it. Add a one-line
   header: "ARCHIVED 2026-09-18 — describes the pre-pivot eSIM product. See
   EXECUTION_PLAN.md for current work."

2. money-manager-web-mvp-v1/ is an unrelated Arabic personal-finance app committed
   into this repo, including a SQLite database and its WAL files. Do NOT delete it.
   Report: its total size, whether money-manager.db is tracked in git, and the exact
   commands to extract it into its own repo preserving history (git subtree split).
   Wait for the human to run them.

3. List every local git branch with its last commit date and whether it is merged
   into main. Recommend which to delete. Do not delete any branch yourself.

4. .gitignore check: confirm .env, money-manager.db*, tsconfig.tsbuildinfo, .next/,
   and .DS_Store are all ignored. tsconfig.tsbuildinfo currently shows as modified
   in git status — if tracked, untrack it.

5. docs/legal/ contains a file named "RECOVERY-CODES-Abdelrahman Abdelwahab.txt"
   in docs/. If that file contains real account recovery codes and is tracked in
   git, STOP and report it prominently — it must be removed from history and the
   codes regenerated. Do not print the contents.

Acceptance criteria:
- [ ] SPRINT_TASKS.md archived with header
- [ ] Extraction commands for money-manager reported, not executed
- [ ] Branch report delivered with recommendations
- [ ] .gitignore verified; build artifacts untracked
- [ ] Recovery-codes exposure explicitly checked and reported
```

---

## M1.3 — Verify the booking payment rail end to end

**Agent B · Owns `src/app/api/stripe/`**

```
The booking → Stripe Connect → webhook path is fully written but has never
executed against a real Stripe account. Verify it in test mode and fix what breaks.

Read first (do not rewrite unless broken):
  src/app/api/stripe/bookings/checkout/route.ts
  src/app/api/stripe/webhook/route.ts
  src/app/api/stripe/connect/onboarding/route.ts
  src/lib/stripe/platformFee.ts
  src/lib/stripe/server.ts

1. Confirm STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET are set locally, and that
   scripts/validate-env.mjs requires them. Add them if missing.

2. Write a documented manual test procedure in docs/TESTING_PAYMENTS.md covering:
   - stripe listen --forward-to localhost:3000/api/stripe/webhook
   - creating a test coach, completing Express onboarding with Stripe test data
   - publishing a session slot
   - booking as a second test user with card 4242 4242 4242 4242
   - the exact SQL to verify: coach_sessions.status, session_bookings.status,
     the platform fee record, and the payout ledger row

3. Audit the checkout route for these specific risks and fix any that are real:
   - amountCents below Stripe's minimum charge for the currency (~£0.30/€0.50)
   - application_fee_amount exceeding the charge amount at high fee percentages
   - the reservation rollback path leaving orphaned session_bookings rows
   - currency mismatch between coach_profiles.currency and the connected account

4. Audit the webhook for:
   - idempotency — replayed events must not double-write the ledger
   - signature verification using the raw body (Next.js App Router body parsing
     is a common failure point here)
   - handling checkout.session.expired → release the slot back to 'available'
   - handling payment_intent.payment_failed → release the slot

5. Add the expired/failed handlers if absent. A slot reserved by an abandoned
   checkout is currently stuck as 'booked' forever — confirm whether this is true
   and fix it if so.

Acceptance criteria:
- [ ] docs/TESTING_PAYMENTS.md exists and a human can follow it start to finish
- [ ] A test booking moves session_bookings to 'confirmed' with the fee recorded
- [ ] An abandoned checkout releases the slot back to 'available'
- [ ] A replayed webhook event writes nothing twice
- [ ] Every issue found is listed in your summary, fixed or explicitly deferred
- [ ] pnpm check passes
```

---

## M1.5 — Booking lifecycle emails

**Agent D · Owns `src/emails/`**

```
Paying clients currently receive nothing but a Stripe receipt. Build booking
confirmation emails for both parties using the existing React Email setup.

Existing patterns to follow: src/emails/waitlist-welcome.tsx and
src/emails/referral-notification.tsx. Match their structure, brand tokens, and
i18n approach (src/emails/i18n.ts). Preview with `pnpm email`.

1. Create src/emails/booking-confirmed-client.tsx:
   coach name, session title, date/time in the CLIENT's timezone, duration,
   amount paid, join link (may be null at this stage — handle gracefully),
   cancellation policy line, link to the session in the dashboard.

2. Create src/emails/booking-confirmed-coach.tsx:
   client display name, session title, date/time in the COACH's timezone,
   duration, payout amount (gross minus platform fee), link to coach dashboard.

3. Send both from the webhook handler in src/app/api/stripe/webhook/route.ts at
   the point the booking flips to 'confirmed'. Critical constraints:
   - Email failure must NEVER fail the webhook. Wrap in try/catch, log the error,
     return 200 to Stripe regardless. A retried webhook that re-sends email is
     worse than a missed email.
   - Read timezones from profiles.timezone; fall back to UTC and label it.
   - Use the existing Resend client and RESEND_FROM.

4. Both templates need a plain-text fallback and must render correctly in dark mode.

Acceptance criteria:
- [ ] Both templates render in `pnpm email` preview with realistic sample data
- [ ] Times display in each recipient's own timezone, labelled
- [ ] A thrown Resend error still returns 200 from the webhook
- [ ] Coach email shows net payout, not gross
- [ ] pnpm check passes
```

---

## M2.1 — Session join links

**Agent C · Owns `src/app/dashboard/coach/`, session pages**

```
A client can currently pay for a session and has no way to attend it. Agora video
is a week of work; a coach-supplied meeting link ships today and unblocks revenue.

1. Migration: add to public.coach_sessions
     meeting_url text
   with a check constraint that it is null or starts with 'https://'.
   Leave agora_channel in place for later.

2. Coach dashboard (src/app/dashboard/coach/): add a meeting URL field to the
   session create/edit form. Validate https:// on the server in actions.ts.
   Label it clearly: "Zoom, Google Meet, or any video link — clients see this
   after they book."

3. Build a session detail page at src/app/dashboard/sessions/[id]/page.tsx,
   readable by the session's coach and its confirmed client only. Show: title,
   coach/client name, start time in the viewer's timezone, duration, status,
   amount, and the join link.

   The join link must be hidden unless the booking status is 'confirmed'. Never
   expose meeting_url to a user who has not paid — verify this at the RLS level,
   not just in the UI.

4. Surface the link 15 minutes before start with a prominent "Join session"
   button; before that show a countdown.

5. Link to this page from the client's billing/bookings list and the coach's
   dashboard session list.

Acceptance criteria:
- [ ] Coach can attach a meeting link when creating or editing a slot
- [ ] Confirmed client sees the join link on the session page
- [ ] A user with an unpaid or cancelled booking cannot read meeting_url — proven
      by a direct Supabase query as that user, not just by the UI hiding it
- [ ] Times render in the viewer's timezone
- [ ] pnpm check passes
```

---

## M3.1 — Cancellation and refunds

**Agent B · Owns `src/app/api/stripe/`**

```
session_bookings supports a 'cancelled' status with a cancelled_at constraint, but
no code ever writes it and no refund is ever issued. Every dispute is currently
manual work in the Stripe dashboard.

Policy to implement (make it configuration, not constants — put it in
src/lib/bookings/cancellationPolicy.ts):
  - more than 24h before start → full refund, slot returns to 'available'
  - within 24h of start        → 50% refund, slot NOT released
  - after start time           → no refund
  - coach cancels, any time    → full refund, slot released, client emailed

1. Create POST /api/stripe/bookings/cancel accepting a bookingId. It must:
   - authenticate and authorize (only that booking's client or coach)
   - load the session start time and compute the applicable refund tier
   - issue the Stripe refund with the correct amount, including reversing the
     application fee proportionally (refund_application_fee)
   - update session_bookings: status='cancelled', cancelled_at=now()
   - release coach_sessions back to 'available' where policy says so
   - be idempotent — a double-submitted cancel must not double-refund

2. Add cancel buttons to the session detail page and the coach dashboard, each
   showing the refund amount the policy will produce BEFORE confirming.

3. Handle the charge.refunded webhook event to keep the ledger consistent.

4. Coordinate with Agent D for cancellation emails to both parties.

Note on Connect refunds: when a payment used transfer_data to a connected
account, reversing it requires reversing the transfer as well. Read Stripe's
current Connect refund documentation before implementing — do not assume the
plain-charge refund flow applies.

Acceptance criteria:
- [ ] Cancel >24h out refunds in full and frees the slot
- [ ] Cancel <24h out refunds 50% and does not free the slot
- [ ] Double-submitting cancel refunds exactly once
- [ ] Platform fee is reversed proportionally, verified in the Stripe dashboard
- [ ] Policy thresholds live in one config file
- [ ] pnpm check passes
```

---

## M3.2 — Coach earnings page

**Agent C**

```
Coaches have no visibility into what they have earned. This is the first question
every coach asks in their first week.

Build src/app/dashboard/coach/earnings/page.tsx showing, for the signed-in coach:

1. Summary tiles: total earned (all time), pending payout, paid out, sessions
   completed this month.
2. A per-session table: date, client display name, gross amount, platform fee,
   net to coach, payout status.
3. A link to the Stripe Express dashboard for payout details and tax documents —
   generate it with stripe.accounts.createLoginLink() in a server action. Do not
   rebuild Stripe's payout UI.

Data comes from session_bookings joined to coach_sessions plus the platform fee
ledger written by the webhook. Read src/app/api/stripe/webhook/route.ts to find
the exact table and column names — do not guess them.

Currency: render using the coach's coach_profiles.currency. Never mix currencies
in a single total; if a coach somehow has bookings in multiple currencies, group
the totals by currency.

Acceptance criteria:
- [ ] Coach sees only their own earnings — verified by RLS, not UI filtering
- [ ] Gross, fee, and net reconcile exactly against the Stripe dashboard for a
      test booking
- [ ] Express dashboard login link works
- [ ] Amounts formatted in the coach's currency with correct minor units
- [ ] pnpm check passes
```

---

## Verification brief — run after each milestone

**Any agent, fresh session**

```
Verify milestone [N] against its exit test in EXECUTION_PLAN.md. You are
verifying, not building — do not fix anything you find, report it.

1. Run pnpm check and report the exact output.
2. Run the RLS test suite against the local Supabase stack and report pass/fail counts.
3. For the milestone's exit test, trace the code path by reading the files
   involved and state whether it can succeed. Name the specific line that would
   fail if it cannot.
4. Check for regressions: list every file changed since the last milestone tag
   and flag anything touching auth, RLS, or payment amounts.
5. Report anything a brief claimed was done that you cannot find evidence of.

Output a short table: exit criterion | verified yes/no | evidence.
Be skeptical. A milestone that "looks done" but has never been executed against
a real Stripe account is not done.
```

---

## Brief-writing notes for future tasks

When you write your own briefs, the ones above work because they:

- **Name exact files.** Agents waste turns searching; `src/app/coaches/page.tsx` costs one line and saves five tool calls.
- **Quote the code being changed.** The agent confirms it is looking at the same thing you are.
- **Say why, in one sentence.** An agent that understands "marketplace cannot bootstrap" makes better judgment calls at the edges than one following instructions blindly.
- **State what NOT to touch.** Scope creep is the main failure mode of capable agents.
- **Put security checks in the acceptance criteria.** "Verified by RLS, not UI filtering" catches the most common and most dangerous shortcut.
- **End with `pnpm check`.** Always.
