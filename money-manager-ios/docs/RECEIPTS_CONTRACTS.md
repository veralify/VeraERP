# Receipts, sync and accounting — shared contracts

The plan is in five phases, built in parallel by separate agents. This file
is the agreement between them. **Build against it exactly. If something here
is wrong or missing, say so in your report; do not quietly change a
contract another phase depends on.**

- Schema: `supabase/migrations/20260925090000_money_receipts_sync_foundation.sql`
  (already applied in the branch; do not edit it — add your own migration).
- Policy tests: `supabase/tests/money_receipts_sync_rls.sql`.
- iOS seam: `money-manager-ios/Veralify/App/Backend.swift`.

## 1. Who owns what

Edit only your own paths. Anything outside them: leave it and report what
you needed.

| Phase | Owns | Migration timestamps |
|---|---|---|
| 0 · iOS sign-in + sync | `money-manager-ios/Veralify/Sync/**`, `Veralify/Auth/**` (new), all files in `Veralify/Models/**` except `ReceiptRecord.swift`, `Veralify/App/**` (not `Backend.swift`), `Features/Account/AccountView.swift`, `money-manager-ios/project.yml`, `money-manager-ios/README.md`, `supabase/functions/account-delete/**` | `20260925100000`–`20260925109999` |
| 1 · Receipt capture + AI | `supabase/functions/ai-gateway/**`, `money-manager-ios/Veralify/Features/Receipts/**` (new), `Veralify/Models/ReceiptRecord.swift` (new), `Features/Dashboard/DashboardView.swift` (entry point only), `VeralifyCore/Sources/VeralifyCore/Receipt*.swift`, `MerchantKey.swift` (new) + tests | `20260925110000`–`20260925119999` |
| 2 · Web dashboard | `src/app/dashboard/money/**` except `integrations/`, `reports/`, `mileage/`; `src/components/money/**`, `src/lib/money/**`, `src/lib/api/database.types.ts` | `20260925120000`–`20260925129999` |
| 3 · Accounting | `supabase/functions/accounting-*/**`, `supabase/functions/_shared/accounting/**`, `src/app/dashboard/money/integrations/**`, `src/app/api/accounting/**`, `money-manager-ios/Veralify/Features/Integrations/**` (new, not wired in) | `20260925130000`–`20260925139999` |
| 4 · Reports + extras | `supabase/functions/fx-rates-sync/**`, `supabase/functions/inbound-receipts/**`, `src/app/dashboard/money/reports/**`, `src/app/dashboard/money/mileage/**`, `src/app/api/money/reports/**`, `money-manager-ios/Veralify/Features/Mileage/**` (new, not wired in) | `20260925140000`–`20260925149999` |

"Not wired in" means: build the screen, but leave adding the link or tab
to the coordinator, who merges all five phases.

**Xcode project.** `Veralify.xcodeproj` is generated from `project.yml` by
XcodeGen (`xcodegen generate`); `sources: - path: Veralify` already picks up
new files and folders. Do not hand-edit `project.pbxproj`. Only Phase 0 edits
`project.yml`.

## 2. Sync protocol (all `money_*` tables with `sync_seq`)

- **Ids come from the client** (UUID v4), so rows can be created offline.
- **Never send** `user_id` values other than the signed-in user, and never send `sync_seq`, `updated_at` or `created_at`: the server sets them.
- **Deletes are soft.** Set `deleted_at`. Readers filter `deleted_at is null`.
- **Push, then pull.** Push local changes by upserting on `id` (PostgREST `Prefer: resolution=merge-duplicates`). Then pull per table with
  `select * where sync_seq > :cursor order by sync_seq limit 500`,
  repeating until fewer than 500 rows come back. Store the highest `sync_seq` seen per table as that table's cursor.
- **Conflicts:** last write wins at row level, in server order. A row edited locally while offline is pushed before pulling, so the local edit wins unless another device wrote later.
- **Money** is `numeric` on the server and `Decimal` on iOS. Send it as a JSON **string** (`"12.50"`), never a float.
- **Dates:** calendar dates as `YYYY-MM-DD`, months as the first day (`YYYY-MM-01`), instants as ISO 8601 with a zone.

### iOS model ↔ table

| SwiftData model | Table | Notes |
|---|---|---|
| `IncomeSource` | `money_income` | `kind` ↔ `type` (`fixed`/`variable`), `isActive` ↔ `active` |
| `IncomeActual` | `money_income_actuals` | `source` ↔ `income_id` |
| `ExpenseItem` | `money_expenses` | |
| `DebtRecord` | `money_debts` | `remoteID` ↔ `local_id`, `extraPayment` ↔ `extra_payment` |
| `DebtPayment` | `money_debt_payments` | `debtRemoteID` → resolve to the debt's UUID `debt_id` |
| `PlanSettings` | `money_settings` | keys `targetMonths`, `startDate`, `payoffStrategy`, `homeCurrency` |
| `TransactionRecord` | `money_transactions` | `name` ↔ `merchant`; `direction` credit/debit ↔ `income`/`expense`; `occurredAt` ↔ `occurred_at` (+ `transaction_date`); `scope`; `account`; `notes`. **Phase 0 adds** `currency: String = "EUR"`, `taxAmount: Decimal?`, `receiptID: UUID?`, `sourceRaw: String = "manual"` to the model. |
| `MoneyLoss` | `money_losses` | `date` ↔ `occurred_on`, `reasonRaw` ↔ `reason` |
| `MonthlySnapshot` | `money_monthly_snapshots` | |
| `CategoryBudget` | `money_budgets` | `category` ↔ `category_key`, `limit` ↔ `monthly_limit` |
| `ReceiptRecord` (Phase 1) | `money_receipts` | client writes id, image_paths, source, transaction_id, deleted_at only |
| — | `money_categories`, `money_merchant_rules` | pulled on iOS; rules also pushed when the user corrects a category |

Every synced model gets `id: UUID` (stable, `@Attribute(.unique)`), `updatedAt`, `deletedAt: Date?` and a local `needsPush: Bool`. New properties need defaults so existing stores migrate without a mapping model.

Stays **local only** for now: `StoredDocument` (the ID vault holds passport numbers), family split models, `QuestCompletion`.

## 3. Categories

`category_key` is the stable identifier everywhere: transactions, budgets, rules, accounting mappings. Seed these keys for every user on first sign-in (Phase 0, in the iOS first-sync and in a server default). Display names are localised on each client:

`groceries, eating_out, transport, fuel, housing, utilities, shopping, health, entertainment, travel, subscriptions, office_supplies, software, professional_services, education, gifts_donations, fees_charges, other`

The existing iOS presets map as: General→`other`, Tools→`office_supplies`, Food→`groceries`, Transport→`transport`, Bills→`utilities`, Shopping→`shopping`, Health→`health`. `money_transactions.category` holds the key.

## 4. Merchant key

`merchant_key` = the merchant name lower-cased, accents removed (NFKD, strip marks), `&` → `and`, every run of non-alphanumerics collapsed to a single space, trimmed, and trailing legal suffixes dropped (`srl`, `s r l`, `spa`, `s p a`, `snc`, `sas`, `ltd`, `limited`, `plc`, `llp`, `inc`, `llc`, `gmbh`). Example: `"ESSELUNGA S.p.A."` → `"esselunga"`, `"Marks & Spencer PLC"` → `"marks and spencer"`.

Implemented once in Swift (`VeralifyCore/MerchantKey.swift`, Phase 1) and once in TypeScript (`supabase/functions/ai-gateway`, Phase 1), and both are tested against the same examples.

## 5. Reading a receipt — `receipts-extract`

1. The app creates the `money_receipts` row (client UUID, `source`, `status` defaults to `uploaded`).
2. It uploads each page as a JPEG to the private `receipts` bucket at
   `{user_id}/{receipt_id}/{page}.jpg` (page from 1, long edge ≤ 1600px, quality ~0.7), then updates `image_paths`.
3. It calls:

```
POST {SUPABASE_URL}/functions/v1/ai-gateway/receipts-extract
Authorization: Bearer <user access token>
apikey: <anon key>
Content-Type: application/json

{ "receipt_id": "uuid", "locale": "it-IT", "home_currency": "EUR" }
```

The gateway checks the row belongs to the caller, checks the monthly scan limit, sets `status = processing`, reads the images with the service role, and calls the `multimodal_primary` model role with a strict JSON schema. It then applies merchant rules and the duplicate check, writes `extraction`, `model`, `prompt_version`, `merchant_key`, `receipt_date`, `total` and `currency`, and sets `status = extracted`. It increments `money_receipt_usage` and returns:

```jsonc
// ReceiptExtraction v1. Each F<T> is { "value": T | null, "confidence": 0..1 }.
// Money is a decimal string.
{
  "version": "1",
  "receipt_id": "uuid",
  "document_type": "receipt" | "invoice" | "scontrino" | "other",
  "merchant": { "name": F<string>, "vat_id": F<string>, "address": F<string>, "country": F<"IT"|"GB"|string> },
  "merchant_key": "esselunga",
  "date": F<"YYYY-MM-DD">,
  "time": F<"HH:MM">,
  "currency": F<"EUR">,
  "total": F<"12.50">,
  "subtotal": F<string>, "tip": F<string>, "discount": F<string>, "tax_total": F<string>,
  "tax_lines": [ { "rate": "22", "taxable": "10.25", "tax": "2.25" } ],
  "line_items": [ { "description": "Latte", "quantity": "1", "unit_price": "1.29", "amount": "1.29" } ],
  "payment": { "method": F<"card"|"cash"|"other">, "card_last4": F<string> },
  "receipt_number": F<string>,
  "category": { "key": "groceries", "confidence": 0.93, "source": "rule" | "model" | "default" },
  "scope_suggestion": "business" | "personal" | null,
  "duplicate_of": "uuid" | null,        // transaction id with same merchant_key, date and total
  "warnings": [ "total_mismatch" | "low_confidence" | "not_a_receipt" | "multiple_currencies" ],
  "model": "google/gemini-…", "prompt_version": "receipts-v1"
}
```

Errors are JSON `{ "error": CODE, "message": "…" }`:

| Status | Code | Meaning |
|---|---|---|
| 401 | `UNAUTHENTICATED` | missing or invalid token |
| 404 | `RECEIPT_NOT_FOUND` | not the caller's receipt |
| 402 | `SCAN_LIMIT_REACHED` | monthly limit (`RECEIPTS_MONTHLY_SCAN_LIMIT`, default 100) |
| 422 | `UNREADABLE` | no receipt found in the image; status set to `failed` |
| 503 | `AI_UNAVAILABLE` | every model in the role failed; safe to retry |

4. The user reviews and confirms. The app inserts the `money_transactions` row with `source = 'receipt'`, `receipt_id`, `currency`, `tax_amount`, `scope` and `category`. A database trigger then marks the receipt `confirmed` and links it; the client cannot set `status` itself. If the user changed the category, the app upserts `money_merchant_rules` for that `merchant_key`.

Offline: steps 1–2 wait in a local queue and run when the phone is back online.

**Server-to-server calls.** `inbound-receipts` (Phase 4) has no user token. `receipts-extract` therefore also accepts `Authorization: Bearer <service role key>` with `"user_id": "uuid"` in the body. It then acts for that user, with the same ownership check against the row, the same scan limit and the same response. Any other caller that sends `user_id` is ignored and treated as the token's user.

## 6. Accounting (Phase 3)

- OAuth runs in edge functions: `accounting-connect` returns the provider's authorize URL (state + PKCE stored in `accounting_oauth_states`), and `accounting-callback` exchanges the code, stores the token bundle in Vault (`vault.create_secret`), and inserts `accounting_connections`.
- Tokens never leave the server. Clients read connection status only (column grants hide `token_secret_id`).
- A trigger (Phase 3's own migration) enqueues `accounting_sync_jobs` when an expense transaction whose `scope` matches a connection's `sync_scope` is created, changed or soft-deleted, while `auto_sync` is on.
- `accounting-sync` is the worker. It claims due jobs (`for update skip locked`), maps category/tax/payment via `accounting_mappings`, and creates or updates the provider record plus the receipt attachment. It records `accounting_links`, then retries with backoff (1m, 5m, 30m, 2h, 12h, then `dead`).
- Each provider is an adapter behind one TypeScript interface in `_shared/accounting/`.

Secrets (Supabase function secrets):

| Name | Used by |
|---|---|
| `OPENROUTER_API_KEY` | exists — receipts-extract |
| `RECEIPTS_MONTHLY_SCAN_LIMIT` | receipts-extract (default 100) |
| `QUICKBOOKS_CLIENT_ID`, `QUICKBOOKS_CLIENT_SECRET`, `QUICKBOOKS_ENVIRONMENT` (`sandbox`/`production`) | accounting |
| `XERO_CLIENT_ID`, `XERO_CLIENT_SECRET` | accounting |
| `FREEAGENT_CLIENT_ID`, `FREEAGENT_CLIENT_SECRET`, `FREEAGENT_ENVIRONMENT` | accounting |
| `FIC_CLIENT_ID`, `FIC_CLIENT_SECRET` | accounting (Fatture in Cloud) |
| `ACCOUNTING_OAUTH_REDIRECT_BASE` | accounting callback URL base |
| `INBOUND_EMAIL_DOMAIN`, `INBOUND_WEBHOOK_SECRET` | inbound-receipts |

## 7. Verification tools in this environment

- **Database:** `KEEP=0 TESTS="supabase/tests/<file>.sql" /tmp/claude-0/-home-user-VeraERP/85e52193-ee23-5cef-b678-46100a26d427/scratchpad/pg-harness.sh <repo root>` runs a fresh Postgres 16 with Supabase stubs, applies every migration and runs pgTAP files.
- **Edge functions:** `deno fmt --check`, `deno lint`, `deno test --allow-env --allow-net --allow-read supabase/functions/<fn>`. Deno 2 is installed; CI runs the same.
- **Web:** `pnpm lint`, `pnpm exec tsc --noEmit`, `NEXT_PUBLIC_SUPABASE_URL=https://example.supabase.co NEXT_PUBLIC_SUPABASE_ANON_KEY=x pnpm build`.
- **iOS:** SwiftUI/SwiftData cannot compile on Linux. `. …/scratchpad/swiftenv.sh` then `swiftc -parse <file>` on every changed Swift file; `swift test` in `VeralifyCore` for pure logic; `REPO=<repo root> …/scratchpad/harness.sh` for the Foundation-only app tests. Put testable logic in VeralifyCore where you can.
