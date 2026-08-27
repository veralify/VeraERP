# ADR-002: Legacy eSIM/travel functionality superseded by fitness pivot

**Status:** ACCEPTED
**Date:** 2026-08-27

## Context

The iOS app contains a legacy eSIM/travel product: `ESIMGoClient`, `ESIMProvisioningManager`,
Duffel flight mocks, travel concierge chat cards (`eSIMCardView`, `FlightCardView`), and
`LocalOrderStore`. The web app contains eSIM order migrations. Spec v2.3 defines Veralify as
a fitness & social platform ("Track. Connect. Transform.") with no travel functionality.

## Decision

1. Legacy travel/eSIM code is **superseded**. It is removed from the active app surface
   (navigation, tabs, tools) during iOS/web foundation work.
2. Film/Foto functionality is explicitly **preserved** per spec §1 and the master directive.
3. Legacy database tables (esim_orders, etc.) are NOT dropped at this stage; a cleanup
   migration is deferred to Phase 13 (hardening) after data review.
4. The generic infrastructure the travel product built — `SupabaseClient`, `BackendService`,
   `KeychainManager`, `LocalizationManager`, AI gateway plumbing, auth — is **retained and reused**.

## Consequences

- iOS tab structure is rebuilt around: Home, Track, ＋ Create, Connect, Profile (spec §40–49).
- The AI concierge tool registry is replaced by the allowlisted Veralify AI tool contract (§61).
- No user-facing travel features remain post-foundation.
