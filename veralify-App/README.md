# Veralify iOS

Veralify iOS is a SwiftUI app for the fitness and social platform: **Track. Connect. Transform.**

## App shell

The active surface is a five-position floating tab shell:

- Home — fitness empty state until Home phase
- Track — food/progress empty state until Track/Food phases
- ＋ Create — action sheet for Log Food, Scan Food, Progress Photo, Post, Go Live, and preserved Shared Film
- Connect — community empty state until Connect phases
- Profile — authenticated account, subscription entry, Shared Film, language, version, and sign out

Legacy travel/eSIM navigation, checkout, and concierge tools were removed from the active surface per ADR-002. Generic chat components remain for the future AI coach.

## Entitlements and purchase flow

```text
Profile / Paywall
    ↓ StoreKit 2 purchase with appAccountToken = Supabase user UUID
POST /api/v1/iap/validate
    ↓ backend verifies Apple signed transaction
user_entitlements
    ↓ fetched by EntitlementStore
App gates features from backend entitlements only
```

No client code grants subscription access from a StoreKit success alone. If `/api/v1/iap/validate` is unavailable, the transaction is logged/queued in memory and the app keeps showing no local entitlement until `user_entitlements` refreshes from Supabase.

## Required configuration

Human App Store Connect actions before live billing:

1. Confirm bundle ID `com.veralify.app`.
2. Create auto-renewable subscriptions:
   - `veralify.pro.weekly`
   - `veralify.pro.monthly`
   - `veralify.pro.annual`
   - `veralify.coach.monthly`
3. Configure the Pro subscriptions in one group with a 3-day introductory trial and localized prices.
4. Configure App Store Server Notifications V2 for the backend Apple notification endpoint.
5. Provide backend Apple App Store Server API credentials and implement `/api/v1/iap/validate`.
6. Ensure Supabase has `user_entitlements` with canonical entitlement keys from the frozen contract.

## Build

```sh
cd veralify-App/iOS/veralify
xcodebuild -project veralify.xcodeproj -scheme veralify -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
