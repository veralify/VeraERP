# Veralify — MVP Sprint Tasks

_AI-agent ready execution plan. Feed each task directly to Cursor / Claude Code / Devin._

**Last updated:** 2026-08-07 15:12 (local)

---

## Sprint Progression

| Sprint | Focus Area | ✅ Done when… |
|--------|-----------|--------------|
| **Sprint 1** | Payments & DB | Real credit card charge → row in `esim_orders` + `stripe_events` |
| **Sprint 2** | Live eSIM Go & AI Concierge | AI chat returns real live eSIM catalog for a given destination |
| **Sprint 3** | Flight Search & TestFlight | AI chat shows live Duffel flights; TestFlight build submitted |

---

## ⚡ SPRINT 1 — Stripe Payments & Webhook Engine

> **Goal:** Users can pay for an eSIM with a real credit card.  
> **Estimated:** 5–7 days

---

### Task 1.1 — Database Schema Migration (`stripe_events`)

**Target file:** `supabase/migrations/20260807000000_create_stripe_events.sql`

**What's done:**
- `profiles` table has `stripe_customer_id` column ✅
- `user_orders` and `esim_orders` tables exist with RLS ✅

**What's missing:**
- No idempotency table → Stripe retries could double-provision eSIMs ❌

**Agent prompt:**
```
Create a Supabase migration file:
  supabase/migrations/20260807000000_create_stripe_events.sql

Define table stripe_events with:
  - id             uuid PRIMARY KEY DEFAULT gen_random_uuid()
  - stripe_event_id text UNIQUE NOT NULL
  - type            text NOT NULL
  - processed_at    timestamptz NOT NULL DEFAULT now()

Enable Row Level Security (RLS).
Add a policy granting ONLY service_role full access.
Do NOT grant public or anon access.
```

**Acceptance criteria:**
- [ ] Migration file exists and runs cleanly via `supabase db push`
- [ ] `stripe_events` table present with unique constraint on `stripe_event_id`
- [ ] RLS enabled, no public access

---

### Task 1.2 — Server-Side Stripe Webhook & eSIM Provisioner

**Target file:** `supabase/functions/vera-stripe-webhook/index.ts`

**What's done:**
- `esim_orders` table schema exists ✅
- `ESIMGoModels.swift` defines order/install structures (reference for backend shape) ✅
- `ESIM_GO_API_KEY` expected in Edge Function env ✅

**What's missing:**
- No `vera-stripe-webhook` Edge Function ❌
- No server-side eSIM Go order placement (iOS currently calls eSIM Go directly — insecure) ❌

**Agent prompt:**
```
Create a Deno TypeScript Edge Function at:
  supabase/functions/vera-stripe-webhook/index.ts

Steps:
1. Read raw request body as text. Verify Stripe signature against
   STRIPE_WEBHOOK_SECRET env var. Return HTTP 400 on failure.

2. On event type payment_intent.succeeded:
   a. Extract event.id — INSERT into stripe_events(stripe_event_id, type).
      On duplicate key (unique violation), return HTTP 200 immediately (idempotent skip).
   b. Read user_id and package_id from payment_intent.metadata.
   c. Call eSIM Go API:
        POST https://api.esim-go.com/v2.4/orders
        Header: X-API-Key: <ESIM_GO_API_KEY env var>
        Body: {
          "type": "transaction",
          "assign": true,
          "order": [{ "type": "bundle", "quantity": 1, "item": "<package_id>" }]
        }
   d. Parse returned orderReference + first eSIM smdpAddress + matchingId.
   e. INSERT into esim_orders (user_id, package_id, order_reference,
      smdp_address, matching_id, status='completed').
   f. UPDATE user_orders SET status='completed' WHERE reference_code = payment_intent.id.

3. Return HTTP 200 on success.
4. If eSIM Go API call fails, return HTTP 500 so Stripe retries.

Use Supabase service_role client (SUPABASE_SERVICE_ROLE_KEY) for all DB writes.
```

**Acceptance criteria:**
- [ ] Function deploys via `supabase functions deploy vera-stripe-webhook`
- [ ] Duplicate Stripe events return 200 without re-provisioning
- [ ] Successful payment creates rows in both `stripe_events` and `esim_orders`
- [ ] No eSIM Go API key in any iOS Swift file

---

### Task 1.3 — iOS Stripe PaymentSheet Integration

**Target files:**
- `veralify-App/iOS/veralify/veralify/Features/Purchase/CheckoutViewModel.swift`
- `veralify-App/iOS/veralify/veralify/Features/Purchase/CheckoutView.swift`

**What's done:**
- `CheckoutView.swift` + `CheckoutViewModel.swift` exist with full UI ✅
- `ESIMGoClient.shared` wired in `CheckoutViewModel` ✅
- Navigation to `ESIMInstallView` already structured ✅

**What's missing:**
- `checkoutService()` in `VeralifyToolRegistry` is a mock returning fake `CheckoutReceipt` ❌
- No Stripe iOS SDK dependency ❌
- No real `PaymentIntent` creation via backend ❌

**Agent prompt:**
```
In CheckoutViewModel.swift, replace the mock checkoutService() call with
real Stripe iOS SDK integration:

1. Add Stripe iOS SDK via Swift Package Manager:
   https://github.com/stripe/stripe-ios (StripePaymentSheet target)

2. Add method createPaymentIntent(packageID: String) -> String:
   - POST to Supabase Edge Function vera-stripe-create-intent
     (or Next.js /api/stripe/create-intent) with { package_id, user_id }
   - Receive { client_secret: String } in response
   - Return client_secret

3. In CheckoutView.swift:
   - On "Pay Now" button tap, call createPaymentIntent()
   - Initialize PaymentSheet with client_secret and
     PaymentSheet.Configuration (business name: "Veralify")
   - Present PaymentSheet from the view
   - On .completed result → set navigation state to show ESIMInstallView
   - On .failed(error) → show error alert
   - On .canceled → dismiss sheet, no state change

4. ESIMInstallView should receive smdpAddress + matchingId
   (fetched from esim_orders after webhook completes, or via polling endpoint).
```

**Acceptance criteria:**
- [ ] Stripe SDK added via SPM, no manual framework embedding
- [ ] `PaymentSheet` presents on "Pay Now" tap
- [ ] Success routes to `ESIMInstallView`
- [ ] No Stripe secret key in Swift code (backend creates PaymentIntent)

---

## 📡 SPRINT 2 — Live eSIM Go & AI Concierge

> **Goal:** AI chat returns real live eSIM plans; OpenAI streaming is live.  
> **Estimated:** 4–6 days  
> **Requires:** Sprint 1 complete (eSIM Go key secured server-side)

---

### Task 2.1 — Secure eSIM Go Catalog Proxy (Edge Function)

**Target file:** `supabase/functions/vera-esim-catalog/index.ts`

**What's done:**
- `ESIMGoClient.swift` calls eSIM Go catalogue directly (client-side) ✅
- `ESIMGoModels.swift` defines full response shapes ✅

**What's missing:**
- API key exposed in iOS build config via `AppConfig.esimGoAPIKey` ❌
- No server-side proxy → key must move to Edge Function env ❌

**Agent prompt:**
```
Create a Deno TypeScript Edge Function at:
  supabase/functions/vera-esim-catalog/index.ts

1. Accept GET requests with optional query param: ?country=JP (ISO alpha-2)
2. Proxy to eSIM Go catalogue:
     GET https://api.esim-go.com/v2.4/catalogue?page=1&perPage=200[&countries=<country>]
     Header: X-API-Key: <ESIM_GO_API_KEY env var>
3. Filter response array to items matching the requested country if provided.
4. Return JSON array with CORS headers:
     Access-Control-Allow-Origin: *
     Access-Control-Allow-Methods: GET, OPTIONS
5. Handle OPTIONS preflight requests.
6. On eSIM Go API error, return HTTP 502 with { error: "Catalog unavailable" }.
```

**Acceptance criteria:**
- [ ] `curl https://<project>.supabase.co/functions/v1/vera-esim-catalog?country=JP` returns real eSIM plans
- [ ] `ESIM_GO_API_KEY` removed from `AppConfig.swift`
- [ ] Function handles missing country param (returns full catalogue)

---

### Task 2.2 — Wire AI Tool `fetch_eSIM_Catalog` to Live Backend

**Target file:** `veralify-App/iOS/veralify/veralify/Core/AI/VeralifyToolRegistry.swift`

**What's done:**
- `fetch_eSIM_Catalog()` function exists and is called by `VeralifyAgentManager` ✅
- `ESIMCatalogItem` model defined ✅
- `eSIMCardView` renders catalog items in chat ✅

**What's missing:**
- `fetch_eSIM_Catalog()` returns 3 hardcoded mock bundles ❌

**Agent prompt:**
```
In VeralifyToolRegistry.swift, replace the mock fetch_eSIM_Catalog()
implementation with a real network call:

1. Build URL: <SUPABASE_URL>/functions/v1/vera-esim-catalog?country=<countryCode>
2. Use URLSession to GET the endpoint.
   Include Authorization: Bearer <SUPABASE_ANON_KEY> header.
3. Decode response JSON array into [ESIMGoCatalogueBundle] (reuse existing model).
4. Map each bundle to ESIMCatalogItem using the same field mapping as
   ESIMPackage.init(bundle:) in ESIMPackage.swift.
5. Return the mapped array.
6. Keep existing guard for 2-letter country code validation.
7. On network error, throw APIError.httpError with the status code.
```

**Acceptance criteria:**
- [ ] Asking Vera "eSIM plans for Japan" returns real plans from eSIM Go
- [ ] `eSIMCardView` renders with live price, data allowance, validity
- [ ] No hardcoded mock bundles remain in `fetch_eSIM_Catalog`

---

### Task 2.3 — Live OpenAI Streaming in AI Gateway

**Target file:** `src/app/api/v1/chat/completions/route.ts`

**What's done:**
- Route exists with full auth, credit guardrail, and SSE streaming infrastructure ✅
- Intent detection (`flight` / `esim` / `general`) works ✅
- Credit deduction + `ai_usage_logs` insert implemented ✅

**What's missing:**
- Entire response is a **mock SSE stream** — no real OpenAI call ❌
- Tool calls (`searchFlights`, `fetch_eSIM_Catalog`) are simulated ❌

**Agent prompt:**
```
Update src/app/api/v1/chat/completions/route.ts to call real OpenAI API:

1. Import OpenAI SDK: import OpenAI from 'openai'
   Initialize with: new OpenAI({ apiKey: process.env.OPENAI_API_KEY })

2. Replace the mock ReadableStream with a real OpenAI streaming call:
   const stream = await openai.chat.completions.create({
     model: body.model ?? 'gpt-4o-mini',
     messages: messages,   // pass through from request body
     stream: true,
     tools: [
       {
         type: 'function',
         function: {
           name: 'searchFlights',
           description: 'Search for flights to a destination on a given date',
           parameters: {
             type: 'object',
             properties: {
               destination: { type: 'string', description: 'IATA code or city name' },
               date: { type: 'string', description: 'ISO date YYYY-MM-DD' }
             },
             required: ['destination', 'date']
           }
         }
       },
       {
         type: 'function',
         function: {
           name: 'fetch_eSIM_Catalog',
           description: 'Fetch eSIM data plans for a country',
           parameters: {
             type: 'object',
             properties: {
               countryCode: { type: 'string', description: 'ISO alpha-2 country code' }
             },
             required: ['countryCode']
           }
         }
       }
     ],
     tool_choice: 'auto'
   })

3. Pipe OpenAI SSE chunks directly to the response stream.
4. After stream completes, run the existing applyPostProcessing()
   with actual token counts from the final usage chunk.
5. Keep the existing 429 credit guard BEFORE the OpenAI call.
6. Keep existing auth (Supabase bearer token validation).
```

**Acceptance criteria:**
- [ ] Web concierge chat returns real OpenAI responses
- [ ] Tool calls (`searchFlights`, `fetch_eSIM_Catalog`) are triggered by OpenAI naturally
- [ ] Credit deduction and `ai_usage_logs` still work
- [ ] `OPENAI_API_KEY` is a server-side env var only (never in client bundle)

---

## ✈️ SPRINT 3 — Flight Search & TestFlight Release

> **Goal:** Live Duffel flight display in AI chat + TestFlight build submitted.  
> **Estimated:** 4–5 days  
> **Requires:** Sprint 2 complete

---

### Task 3.1 — Duffel Flight Search Edge Function

**Target file:** `supabase/functions/vera-duffel-search/index.ts`

**What's done:**
- `FlightCardView.swift` renders flight results in chat ✅
- `FlightOption` model defined in `VeralifyToolRegistry.swift` ✅

**What's missing:**
- No Duffel HTTP client anywhere in the repo ❌
- `searchFlights()` returns 3 hardcoded mock flights ❌

**Agent prompt:**
```
Create a Deno TypeScript Edge Function at:
  supabase/functions/vera-duffel-search/index.ts

1. Accept POST with JSON body: { origin: string, destination: string, departure_date: string }
2. Call Duffel API:
     POST https://api.duffel.com/air/offer_requests?return_offers=true
     Headers:
       Authorization: Bearer <DUFFEL_API_KEY env var>
       Duffel-Version: v2
       Content-Type: application/json
     Body:
       {
         "data": {
           "slices": [{ "origin": origin, "destination": destination, "departure_date": departure_date }],
           "passengers": [{ "type": "adult" }],
           "cabin_class": "economy"
         }
       }

3. From the response, take the top 3 cheapest offers.
4. Map each offer to simplified JSON:
   {
     id, airline, flight_number, origin, destination,
     departure_time, arrival_time, stops, price, currency, deep_link
   }
   Use offer.owner.name for airline, offer.slices[0].segments[0].marketing_carrier_flight_number
   for flight_number, offer.total_amount for price.
   deep_link = "https://duffel.com" (placeholder until booking is wired)

5. Return JSON array with CORS headers.
6. On Duffel API error, return HTTP 502.
```

**Acceptance criteria:**
- [ ] POST to function with `{ origin: "LHR", destination: "DXB", departure_date: "2026-09-01" }` returns 3 real offers
- [ ] `DUFFEL_API_KEY` is Edge Function env only, never in iOS
- [ ] Response maps cleanly to `FlightOption` model in iOS

---

### Task 3.2 — Wire iOS Concierge `searchFlights` to Live Backend

**Target file:** `veralify-App/iOS/veralify/veralify/Core/AI/VeralifyToolRegistry.swift`

**What's done:**
- `searchFlights()` called by `VeralifyAgentManager` ✅
- `FlightCardView` renders results in `ChatView` ✅

**What's missing:**
- `searchFlights()` returns hardcoded Emirates/Qatar/Turkish mock data ❌

**Agent prompt:**
```
In VeralifyToolRegistry.swift, replace the mock searchFlights() with a
real network call:

1. Build URL: <SUPABASE_URL>/functions/v1/vera-duffel-search
2. POST JSON body: { "origin": "LON", "destination": destination, "departure_date": date }
   Use "LON" as default origin (update to use user profile origin city in v2).
3. Include Authorization: Bearer <SUPABASE_ANON_KEY> header.
4. Decode JSON response array into [FlightOption] using the simplified
   schema returned by vera-duffel-search.
5. On network error, throw APIError.httpError with status code.
6. On tap "Book" in FlightCardView, open deep_link in system browser
   via UIApplication.shared.open().
```

**Acceptance criteria:**
- [ ] Asking Vera "flights to Tokyo next week" shows real Duffel results
- [ ] `FlightCardView` renders live airline, price, times
- [ ] "Book" button opens browser with deep link
- [ ] No hardcoded mock flights remain

---

### Task 3.3 — Production Config Audit for TestFlight

**Target files:**
- `veralify-App/iOS/veralify/veralify/Core/Config/AppConfig.swift`
- `veralify-App/iOS/veralify/veralify/veralifyApp.swift`

**What's done:**
- `AppConfig.swift` has placeholder comments warning against embedding keys ✅
- Supabase URL + Anon Key structure exists ✅

**What's missing:**
- `esimGoAPIKey` still a placeholder in `AppConfig` (must confirm removed after Sprint 2) ❌
- No startup health check validating backend connectivity ❌
- No explicit confirmation that secret keys are absent from bundle ❌

**Agent prompt:**
```
Audit and harden AppConfig.swift and veralifyApp.swift for TestFlight:

1. In AppConfig.swift:
   - Confirm esimGoAPIKey is empty string "" (key moved to Edge Function in Sprint 2)
   - Confirm no STRIPE_SECRET_KEY, DUFFEL_API_KEY, or OPENAI_API_KEY exists
   - Supabase URL and Anon Key should come from Info.plist build settings
     ($(SUPABASE_URL) and $(SUPABASE_ANON_KEY) Xcode build config vars)

2. In veralifyApp.swift, add a startup validation in the @main App struct:
   - On appear, call BackendService.shared.healthCheck()
   - healthCheck() should GET <SUPABASE_URL>/functions/v1/vera-esim-catalog?country=GB
   - If response is non-200, log a warning (do NOT block the UI — fail silently in prod)

3. Verify Info.plist has:
   - NSFaceIDUsageDescription set
   - Privacy descriptions for camera (Films feature) and notifications

4. Set CFBundleShortVersionString to "1.0.0" and CFBundleVersion to "1".
```

**Acceptance criteria:**
- [ ] `grep -r "STRIPE_SECRET\|DUFFEL_API\|OPENAI_API\|esim-go.*key" veralify-App/` returns no matches
- [ ] App builds cleanly for Release scheme in Xcode
- [ ] Info.plist privacy strings present
- [ ] TestFlight build successfully uploaded to App Store Connect

---

## 📋 Full Task Checklist

### Sprint 1 — Stripe Payments
- [ ] **1.1** `stripe_events` migration created and deployed
- [ ] **1.2** `vera-stripe-webhook` Edge Function deployed and tested
- [ ] **1.3** iOS `PaymentSheet` integrated in `CheckoutView`

### Sprint 2 — Live eSIM Go & AI
- [ ] **2.1** `vera-esim-catalog` Edge Function deployed; `ESIM_GO_API_KEY` removed from iOS
- [ ] **2.2** `fetch_eSIM_Catalog` tool wired to live backend
- [ ] **2.3** OpenAI real streaming live in `/api/v1/chat/completions`

### Sprint 3 — Flights & Release
- [ ] **3.1** `vera-duffel-search` Edge Function deployed and tested
- [ ] **3.2** `searchFlights` iOS tool wired to live backend
- [ ] **3.3** Config audit passed; TestFlight build submitted

---

_Tasks feed directly into `docs/PROJECT_STATUS.md` MVP To-Do section. Update both files as tasks complete._
