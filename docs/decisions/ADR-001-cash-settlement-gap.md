# ADR-001: Cash settlement for real-world coaching is OUT OF SCOPE pending decision

**Status:** OPEN — architecture blocker isolated
**Date:** 2026-08-27

## Context

The spec (v2.3 §34b) fully defines **online** marketplace payments via Stripe Connect
(session_payment_intents, coach_transactions, coach_payouts, coach_platform_fees, refunds).

The product direction includes real-world coaching (gym/studio/outdoor/home) in markets
such as Egypt and Italy, where **cash collection** may be required. The spec does NOT
define a provider-neutral cash settlement ledger (payment_method, cash payment states,
coach receivable, settlement, cash disputes, no-show/cancellation fees, country-specific
rules, currency handling, marketplace ledger, coach balance).

## Decision

Per the master directive: **do not invent accounting rules.**

1. Implementation proceeds for fully specified **online** flows only (Stripe Connect).
2. `session_bookings.payment_state` uses the frozen state machine
   (`pending → payment_required → paid → confirmed → completed | cancelled | refunded`)
   and `session_payment_intents` carries `UNIQUE(session_id)`.
3. A `payment_method` discriminator is reserved in the booking flow design with the single
   supported value `stripe` at launch. `cash` is rejected at the API boundary.
4. Cash settlement requires a future ADR covering the full list in the directive before any
   schema or code lands.

## Consequences

- Real-world (in-person) coaching sessions are bookable and payable **online only** at launch.
- No cash ledger tables are created; no partial/ambiguous accounting exists in the schema.

## EXACT HUMAN ACTION REQUIRED

Product owner must decide: is cash collection required for launch markets (Egypt/Italy)?
If yes → commission ADR-00X defining the cash settlement ledger before Phase 10 completes.
