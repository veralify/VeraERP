# Money Manager — Competitive Gap Analysis

**Date:** 2026-09-19
**Scope:** Whole product (web MVP), with mobile call-outs for the parallel SwiftUI iOS app
**Code reviewed:** `money-manager-web-mvp-v1/server.js` (710 lines), `money-manager-web-mvp-v1/public/app.js` (1,599 lines), `public/index.html`, `README.md`
**Author:** money-manager-research

> Note on the iOS app: `/Users/abdelwahab/veralify/money-manager-ios/` does not exist on disk as of this date.
> The mobile call-outs below are written against the stated intent (local-first SwiftData, iOS 18+) rather than
> against code, and are marked Medium confidence for that reason.

---

## 1. Summary — the findings that matter, stated as decisions

**S1. Fix the first-run experience before building any new feature. The app currently opens on a red failure state built from fake data.**
This is verified arithmetic, not an opinion. `seed()` (`server.js:96-113`) inserts a €1,600 salary, €1,194 of expenses — two of which (`Intesa San Paolo` €178, `UniCredit` €316) are debt installments *also* present in the `debts` table as `minimum_payment` — and €15,343.25 of debt. The dashboard therefore computes `netCashFlow = 1600 − 1194 − 993.73 − 0 = −587.73` (`server.js:471`), renders the negative branch of the focus card — *"خطتك تحتاج إلى تعديل"* / "your plan needs adjustment" (`app.js:249-255`) — and `/api/plan` reports `available = 406` against a required monthly of roughly €1,000, so the plan badge reads *"تحتاج تعديل"* (not feasible). A brand-new user's very first screen is a personal-finance crisis that belongs to somebody else. **Decision: replace `seed()` with a first-run setup flow; make demo data opt-in and clearly labelled.** *High confidence.*

**S2. Build a rules engine for categorization. It is the single highest-leverage feature, and the open-source peers hand you the design.**
Every transaction defaults to `'Uncategorized'` (`server.js:61`, `server.js:203`), `category` is a free-text input with no taxonomy (`app.js:771`), and there is no rules table, no auto-categorization, and no learning anywhere in the codebase. Actual Budget, Firefly III and Maybe Finance all converged on the same shape: conditions → actions, evaluated on import and re-runnable over history. Maybe's entire engine ships with **three** condition filters (`transaction_amount.rb`, `transaction_merchant.rb`, `transaction_name.rb`) — proof that a useful v1 is small. **Decision: ship a `rules` table with merchant/amount/direction conditions and category/notes/subscription-link actions, applied at import and re-runnable.** *High confidence.*

**S3. `income.type` already has a `'variable'` value that no calculation reads. Fixing that is a correctness bug, not a feature.**
The column exists (`server.js:17`), the form offers ثابت/متغير (`app.js:1148`), the table renders it (`app.js:977-984`) — and then `debtPlan()` and `/api/dashboard` both do a flat `SUM(amount) WHERE active=1` (`server.js:433`, `server.js:462`). A user who honestly marks income as variable gets a plan that treats it as guaranteed, and a feasibility verdict that is falsely confident. Expenses have no variable concept at all. **Decision: add `amount_min`/`amount_max` (or a conservative `planning_amount`) and plan against the conservative figure, mirroring YNAB's "budget what you actually have."** *High confidence.*

**S4. The debt engine already computes monthly interest and throws it away. Snowball-vs-avalanche comparison is a ~150-line server change on an engine that already works.**
`simulate()` accumulates `interest` per month and pushes it into the schedule (`server.js:411-428`), but `debtPlan()` never surfaces it in the response — the `months` mapping drops it (`server.js:452-457`). The payoff ordering is a hardcoded APR-descending sort (`server.js:422`). Undebt.it's entire differentiator is running both methods over the same numbers and showing the delta in money and months. You are one sort-key parameter and one summing loop away from the same thing. **Decision: parameterize the ordering, return `totalInterest` and `payoffMonth` per strategy, and render a two-column comparison.** *High confidence.*

**S5. Do not build bank aggregation, and do not build a cloud notification service. Both trade away the product's actual advantage.**
The app's differentiator is that the data sits in a SQLite file on the user's machine with no account and no third party. Plaid/TrueLayer-style linking is a compliance program, not a feature. Server-push notifications need a job runner and a delivery identity — i.e. an account. The honest answer for the web app is an in-app due-date centre plus an ICS calendar export; the honest answer for iOS is `UNUserNotificationCenter` local notifications, which need no server at all and are strictly better than anything the web app can do. **Decision: notifications are an iOS-first feature; the web app gets a bills calendar and `.ics` export.** *High confidence.*

---

## 2. What we have today — verified from code

### Data model (`server.js:12-94`)

Nine tables: `income`, `expenses`, `debts`, `savings`, `transactions`, `subscriptions`, `admin_tasks`, `documents`, `settings`.

| Table | Notable columns | Notable absences |
|---|---|---|
| `income` | `amount`, `type` ('fixed'/'variable'), `payday`, `active` | `type` is never read by any calculation |
| `expenses` | `amount`, `category` (default `'Fixed'`), `due_day`, `active` | no variable/irregular flag, no cadence (monthly is assumed) |
| `debts` | `balance`, `apr`, `minimum_payment`, `due_day`, `priority` | no payment history, no original balance, no payoff milestones |
| `transactions` | `transaction_date`, `merchant`, `amount` (≥ 0), `direction`, `category` (default `'Uncategorized'`), `account` (free text), `notes` | no FK to anything, no `subscription_id`, no import batch id, no dedupe key |
| `subscriptions` | `amount`, `cadence` ('monthly'/'yearly' only), `next_charge_date`, `trial_ends_on` | no link to `transactions`; entirely manual |
| `settings` | `targetMonths` (16), `startDate` | — |

There is **no** `accounts` table, no `categories` table, no `rules` table, no `budgets` table, no `notifications` table, and no schema migration mechanism (`db.exec` with `CREATE TABLE IF NOT EXISTS` only — adding a column to a shipped DB will silently do nothing).

### API (`server.js`)

REST CRUD per table, plus `/api/dashboard` (:461), `/api/plan` (:460), `/api/upcoming-bills` (:402), `/api/cashflow-sankey` (:481), `/api/transactions/import-file` (:233), `/api/settings` (:284-292), `/api/health` (:118).

### Debt engine (`server.js:407-459`) — the strongest part of the product

`simulate()` runs a month-by-month loop: accrue interest at `apr/100/12`, pay minimums capped by remaining balance, then push all surplus at the highest-APR debt with `priority` as tie-breaker. `debtPlan()` binary-searches 50 iterations for the minimum monthly budget that clears everything inside `targetMonths`, then declares feasibility against `available = max(0, income − expenses)`. This is a genuinely good engine. It is also strictly avalanche, and it discards the interest figures it computes.

### Verified gaps and defects

- **No onboarding of any kind.** `seed()` runs on an empty `income` table; `app.js:1599` is literally `setPage("dashboard")`. No wizard, no empty state at the app level, no demo/real distinction.
- **No categorization.** Free-text `category`, default `'Uncategorized'`, no rules, no learning, no category list endpoint. The only category-aware code is a `WHERE category=?` filter (`server.js:214`) and a `LIKE` search (`server.js:212`).
- **CSV import rejects ordinary bank statements.** `validAmount` requires `Number(value) >= 0` (`server.js:185`) and `normalizeTransaction` requires an explicit `direction` column (`server.js:206`). A standard statement with signed amounts and no `direction` column fails on row 2 and the *entire* import is rejected (`server.js:246`). There is no column-mapping UI, no date-format picker, no duplicate detection, and no preview — the insert is all-or-nothing inside one transaction (`server.js:250`).
- **Month-label timezone bug.** `server.js:453` uses `d.toISOString().slice(0,7)` on a local-midnight `Date`. In UTC+1/+2 (the seed data is Italian) `2026-09-01` local serializes as `2026-08-31T22:00Z`, so every plan row is labelled with the **previous month**. The same pattern at `server.js:473` mis-scopes the current-month transaction totals in the early hours of the 1st. The codebase already contains `toLocalDateStr()` *with a comment explaining exactly this bug* (`server.js:303-308`) — it just is not used in these two places.
- **Seed data double-counts debt.** Two debt installments exist simultaneously as `expenses` rows and as `debts.minimum_payment`, which is what drives the negative first-run dashboard (see S1).
- **Dead UI markup.** `index.html` ships `#search-input`/`#search-form`, `#topbar-add`, a `#confirm-modal`, and a `#toast-host` with `aria-live="polite"`. `app.js` references **none** of them (grep count: 0 each) and still uses native `confirm()` (`app.js:1335`) and `alert()` (`app.js:1118`, `:1120`, `:1347`).
- **Latin digits in an Arabic-first UI.** `fmt()` hardcodes `Intl.NumberFormat("en-US", …)` (`app.js:74-79`). Every amount in the RTL interface renders as `€1,600.00` with Latin digits and Western grouping. Whether that is wrong is a product decision (many Gulf/Levant users prefer Latin digits for money), but it is currently an accident, not a decision — there is no locale setting.
- **No PWA, no service worker, no manifest, no offline shell, no notifications, no auth, no tests, no multi-currency** (`€` is hardcoded in `server.js:518` and `server.js:601`).

**Things that are already fine — no change needed:** the debt simulation core, the Sankey cash-flow widget and its section-focused views (`server.js:481-610`), the period-comparison logic with its planned-vs-actual fallback (`server.js:355-401`), the due-day clamping in `nextOccurrence()` (`server.js:313-326`, correctly handles day 31 in February), the responsive off-canvas nav (`app.js:39-72`), and the theme-token-driven Chart.js theming (`app.js:519-548`). These are above MVP quality and should be left alone.

---

## 3. Competitor scan

### 3a. Local-first open-source peers — closest architectural match

#### Actual Budget — *the single most borrowable product in this list*

Local-first, one SQLite file per budget, optional CRDT sync with client-side encryption; MIT-licensed.
Source: [actualbudget.org/docs](https://actualbudget.org/docs/budgeting/rules/), [github.com/actualbudget/actual](https://github.com/actualbudget/actual)

**Rules engine.** Conditions support `is` / `is not` / `contains` / `does not contain` / `matches` (regex) / `one of` / `not one of`, over fields: imported payee, payee, account, category, date, notes, amount, amount-inflow, amount-outflow, cleared. Actions set category, payee, notes, cleared, account, date, amount, and can prepend/append to notes. Rules run in three stages — `pre`, `default`, `post` — and **within a stage are auto-ranked least-specific to most-specific**, so a broad `contains` rule runs before a precise `is` rule and the specific one wins. All string matching is case-insensitive.
Source: [actualbudget.org/docs/budgeting/rules](https://actualbudget.org/docs/budgeting/rules/)

**Learning.** Two automatic rule types. Renaming a payee prompts "automate this?" and writes a `pre`-stage rule. Categorization learning picks "the best category for a transaction (basically the most common one)" and writes a `default`-stage rule. Both can be disabled per-payee or globally.
Source: [actualbudget.org/docs/budgeting/rules](https://actualbudget.org/docs/budgeting/rules/)

**Import.** CSV, QIF, OFX, QFX, CAMT. The CSV path has an explicit **field-mapping UI** ("Choose field…" per column), a **date-format dropdown** that turns dates green when they parse, a "**split amount into separate inflow/outflow columns**" toggle, a "**flip amount**" toggle, and a multiplier. Duplicate detection uses transaction IDs for OFX/QFX and date + amount + payee otherwise.
Source: [actualbudget.org/docs/transactions/importing](https://actualbudget.org/docs/transactions/importing/)

**Schedules.** Anticipated recurring or one-off transactions that surface as "upcoming" in the register over a user-chosen window (1 week / 1 month / end of month), with per-schedule "automatically add transaction" vs manual approval. Schedules match existing transactions within a **±2-day window**, and integrate with rules to set category on post. A tilde (`~`) marks approximate amounts for variable bills like utilities.
Source: [actualbudget.org/docs/schedules](https://actualbudget.org/docs/schedules/)

**Goal templates — the best answer anywhere to variable/irregular expenses.** Category-note directives: `#template 50 up to 100`; `#template 500 repeat every 3 months starting 2025-01-01`; `#template 10000 by 2025-12` (divides a lump sum across remaining months); `#template 500 by 2025-03 repeat every year`; `#template average 6 months`; `#template average 3 months increase 20%`; `#template copy from 12 months ago`; `#template 15% of all income`; `#template remainder 2`; and `#template-1` priority ordering.
Source: [actualbudget.org/docs/experimental/goal-templates](https://actualbudget.org/docs/experimental/goal-templates/)

**Onboarding.** Honestly, Actual's is *weak* — a branch-by-technical-comfort page rather than a wizard. Its useful contribution is the **no-strings demo budget**, i.e. the explicit separation between "look at fake data" and "start my real file" that Money Manager currently conflates.
Source: [actualbudget.org/docs/getting-started/roadmap-for-new-users](https://actualbudget.org/docs/getting-started/roadmap-for-new-users/)

**Verdict: adopt heavily.** Same architecture (local SQLite, self-hosted, privacy-first), permissive license, and the rules/import/schedules designs are directly transplantable. The three-stage rule ordering is over-engineering for v1 here; the specificity ranking is not.

#### Firefly III — the maximalist rules engine

Source: [docs.firefly-iii.org](https://docs.firefly-iii.org/how-to/firefly-iii/features/rules/)

**Rules.** Organized into ordered **rule groups**. A rule is **strict** (ALL triggers must hit) or non-strict (ANY is enough). Every trigger can be inverted with a NOT box. Text triggers come in *starts with / ends on / contains / is exactly* varieties. "**Stop processing**" exists at three levels: rule (skip the rest of the group), trigger (non-strict only), and action. Rules fire on transaction create, on update, and **manually against existing transactions** from the rule-group menu — retroactive application is explicit and supported.
Source: [docs.firefly-iii.org/how-to/firefly-iii/features/rules](https://docs.firefly-iii.org/how-to/firefly-iii/features/rules/)

**Triggers.** ~40+, grouped as: description/notes/attachment text; properties (type, reconciled, has-attachment/category/budget/tag/notes); amount and foreign amount with `>` `<` `=` plus currency; account (id, name, IBAN, number, is-cash); metadata (tags, SEPA CI, category, budget, subscription, external id, internal reference, URL); and date/time (transaction, interest, book, process, due, payment, invoice, created, updated) supporting `today`, absolute `YYYY-MM-DD`, relative `+3d`/`-2w`, and semi-specific `xxxx-xx-10` for monthly patterns.
Source: [docs.firefly-iii.org/references/firefly-iii/rule-triggers](https://docs.firefly-iii.org/references/firefly-iii/rule-triggers/)

**Subscriptions/bills.** Fields include description, repeat period, **minimum and maximum amount** (an average expected spend — this is their variable-bill answer), first date ("purely cosmetic", used for prediction), a **skip** field for every-Nth cadences, and optional end/extension dates that trigger notifications. Critically: after creating a subscription Firefly **redirects you into a pre-filled rule** that matches on amount and description — bills and rules are the same mechanism. Firefly explicitly does **not** auto-detect subscriptions from transaction history.
Source: [docs.firefly-iii.org/how-to/firefly-iii/finances/subscriptions](https://docs.firefly-iii.org/how-to/firefly-iii/finances/subscriptions/)

**Recurring transactions & notifications.** Recurring transactions actually materialize new transactions on a schedule and **require a cron job**. Notifications go to email (SMTP/Mailgun/Sparkpost/Mailersend), Slack via Incoming Webhook, and Discord/Mattermost by appending `/slack` to the webhook URL.
Sources: [docs.firefly-iii.org/how-to/firefly-iii/finances/recurring](https://docs.firefly-iii.org/how-to/firefly-iii/finances/recurring/), [docs.firefly-iii.org/how-to/firefly-iii/advanced/notifications](https://docs.firefly-iii.org/how-to/firefly-iii/advanced/notifications/)

**Verdict: study the taxonomy, copy roughly 10% of it.** Firefly's 40-trigger surface is what a rules engine looks like after eight years of feature requests, and it is a warning as much as a model. Two things to take: (1) strict/non-strict as a single explicit toggle instead of nested boolean UI, and (2) **rules-as-the-bill-matching-mechanism** — one concept, two features. The cron requirement is exactly the dependency Money Manager should refuse.

#### Maybe Finance — the cautionary tale with a clean rules model

Ruby on Rails, AGPLv3, **archived read-only on 2025-07-27** — the repo is no longer maintained.
Source: [github.com/maybe-finance/maybe](https://github.com/maybe-finance/maybe)

The rules subsystem lives at `app/models/rule/` with `action.rb`, `action_executor.rb`, `condition.rb`, `condition_filter.rb`, and a `registry.rb` plus per-type subdirectories — a pluggable registry where new condition and action types register without touching core logic. The shipped condition filters are exactly three: `transaction_amount.rb`, `transaction_merchant.rb`, `transaction_name.rb`. Maybe also shipped optional AI rule-creation via OpenAI.
Source: [github.com/maybe-finance/maybe/tree/main/app/models/rule](https://github.com/maybe-finance/maybe/tree/main/app/models/rule)

**Verdict: adopt the scope, not the code.** The most useful single data point in this entire report is that a well-funded, well-engineered competitor shipped a production rules engine with **three** condition types. That is the v1 target. The archived status is also a reminder that "open-source personal finance app" is a hard business, not a hard engineering problem.

### 3b. Commercial budgeting / net-worth

#### Copilot Money — best-in-class categorization, Apple-native

Per-user ML model. Signals: "the name of the transaction, amount, day of the week, which card was used, and a few other data points." It activates only after the user has reviewed **30 transactions** — "Once you reach that threshold, Intelligence will be automatically trained on how you want things categorized." It withholds low-confidence predictions: "If Copilot Intelligence can't find a pattern and is not very confident in the prediction, it won't apply it." On a wrong guess it "will surface the top two guesses at the front of the list."
Source: [help.copilot.money/…/copilot-intelligence-for-spending](https://help.copilot.money/en/articles/8182433-copilot-intelligence-for-spending)

Eight widgets: Daily Spending, Spending Category, Budgets (up to four), Net Worth, Credit Card, Account, Recent Transactions, Transactions To Review.
Source: [help.copilot.money/…/adding-widgets](https://help.copilot.money/en/articles/9834331-adding-widgets)

**Verdict: steal the interaction design, not the ML.** Three transferable ideas, all cheap: (1) a **confidence threshold** — never auto-apply a guess you are not sure of, leave it `Uncategorized` and mark it for review; (2) **top-two suggestions** surfaced at the front of the category picker; (3) an explicit **"to review" queue** as a first-class destination. A per-user ML model is not justified here — a deterministic rules engine plus most-common-category learning (Actual's approach) gets most of the value at a fraction of the cost and stays explainable, which matters more for a single-user local app. *Medium-high confidence.*

#### Monarch Money — the recurring-review flow and the bills calendar

Detection is automatic on sync, but gated: Monarch "attempt[s] to detect any new recurring items" and then "presents them to you for review and approval before they are considered recurring items" — a named **Recurring Review flow** surfaced via badge and banner. Reminders: push or email **3 days before** a recurring transaction is expected, configurable under Settings → Notifications. The recurring view has a **colour-coded calendar**: green = paid as expected, yellow = paid at a different amount, blue = upcoming, red = missed.
Sources: [help.monarch.com/…/Tracking-Recurring-Expenses-and-Bills](https://help.monarch.com/hc/en-us/articles/4890751141908-Tracking-Recurring-Expenses-and-Bills), [help.monarch.com/…/Getting-Started-with-Bill-Sync](https://help.monarch.com/hc/en-us/articles/29446697869076-Getting-Started-with-Bill-Sync)

Onboarding leads with account connection, then category review, then goals.
Source: [help.monarch.com/…/Getting-Started-with-Monarch](https://help.monarch.com/hc/en-us/articles/360048393272-Getting-Started-with-Monarch)

**Verdict: adopt the calendar's four-state colour vocabulary and the review-before-commit pattern.** Money Manager already computes upcoming bills (`server.js:328-344`) and already renders alerts (`app.js:382-396`); it is missing the *paid / paid-different / upcoming / missed* distinction, which requires matching `transactions` against `expenses.due_day` and `subscriptions.next_charge_date`. The account-connection-first onboarding is not applicable — there is no aggregation. *High confidence.*

#### YNAB — the method answer for irregular income

Rejects forecasting: budget only money already on hand. For irregular income the prescribed steps are (1) compute average monthly expenses from the full list of monthly bills, non-monthly expenses and goals; (2) prioritize by answering, in order — what must this cover before the next paycheck, what large/infrequent expenses are coming, what can I set aside for *next month*, what goals should I fund, what needs adjusting; (3) in feast months "set some of that money aside for the next month or next few months", building a **Variable Income Fund**; (4) reallocate freely — "changing your plan isn't a failure, it's a feature."
Sources: [ynab.com/guide/irregular-income](https://www.ynab.com/guide/irregular-income), [support.ynab.com/…/using-ynab-with-variable-income](https://support.ynab.com/en_us/using-ynab-with-variable-income-an-overview-BynJaHZ09)

**Verdict: adopt the conservative-planning principle, reject envelope budgeting wholesale.** The transferable idea is one line of logic: when income is variable, plan against a conservative figure and treat the excess as a buffer. Full zero-based envelope budgeting would be a different product and would fight the existing income/expenses/debts model rather than extend it. *High confidence.*

### 3c. Debt payoff specialists

#### Undebt.it — the comparison UX to copy

Runs both methods over the same balances, rates and minimums and "shows you the difference in dollars and months." The engine described is functionally identical to `simulate()`: "accrues interest on each balance, applies your payments, retires debts in order, and rolls freed-up minimums forward until every balance hits zero." Users can flip snowball ↔ avalanche ↔ custom "and compare without re-entering a thing", add one-off extra payments, and it offers 8 accelerated methods including a fully custom ordering. Notably it advertises that calculations run in-browser with no signup — the same privacy posture as Money Manager.
Sources: [undebt.it/blog/debt-snowball-vs-avalanche](https://undebt.it/blog/debt-snowball-vs-avalanche/), [undebt.it/snowball-debt-info.php](https://undebt.it/snowball-debt-info.php)

#### Debt Payoff Planner / DebtFree category

Common feature vocabulary across the category: a **debt-free date** that "updates in real time as you make changes"; drag-to-reorder custom payoff sequence with instant recalculation; milestone celebration; and a **What-If tool** showing "exactly how each change impacts your payoff date and total interest."
Sources: [debtpayoffplanner.com](https://www.debtpayoffplanner.com/), [apps.apple.com/us/app/debt-payoff-planner-tracker](https://apps.apple.com/us/app/debt-payoff-planner-tracker/id1009323715), [apps.apple.com/us/app/debtfree-payoff-planner](https://apps.apple.com/us/app/debtfree-payoff-planner/id6760978185)

**Verdict: adopt.** Money Manager's engine is already better than most of this category's — it binary-searches the *required* budget rather than just simulating a given one, which none of these advertise. What it lacks is entirely presentational: a debt-free **date** (it shows a month index), total interest, per-strategy comparison, and milestones. *High confidence.*

#### Tally — study why it died

Shut down **August 2024** (not 2022), after failing to raise; it had raised $172M and was valued at $855M. The mechanism: Tally's model was lending — refinancing card debt via a lower-interest line of credit. When the Fed moved from near-0% to over 5% between March 2022 and mid-2023, Tally's cost of capital spiked, the spread compressed, and previously profitable loans became loss-makers. A pivot to B2B in April 2024 preceded the shutdown by under six months.
Sources: [techcrunch.com/2024/08/12/…](https://techcrunch.com/2024/08/12/a16z-backed-fintech-tally-which-raised-172m-in-funding-is-shutting-down-after-running-out-of-cash), [bankingdive.com/news/fintech-tally-closes-over-failure-to-raise-capital](https://www.bankingdive.com/news/fintech-tally-closes-over-failure-to-raise-capital/724263/)

**Verdict: the lesson is about monetization, not features.** Tally died from balance-sheet exposure, not from a bad payoff algorithm. A local-first planner that never touches the user's money has no such exposure — and also no lending revenue. Do not read Tally's death as "debt payoff apps don't work"; read it as "do not put a rate-sensitive balance sheet under a planning tool." *High confidence.*

### 3d. Subscription tracking

#### Rocket Money

Detects subscriptions by analyzing connected-account transaction history using pattern recognition against a database of known subscription merchants, alerts on any newly detected recurring charge, and specifically surfaces **free trials that converted to paid**, forgotten annual charges, duplicate services, and **price increases**. All recurring items live in one "Recurring" tab.
Sources: [help.rocketmoney.com/…/managing-your-bills-and-subscriptions](https://help.rocketmoney.com/en/articles/2185531-managing-your-bills-and-subscriptions), [rocketmoney.com/feature/manage-subscriptions](https://www.rocketmoney.com/feature/manage-subscriptions)

#### Lunch Money — the detection heuristic you can actually implement

"Lunch Money will automatically detect recurring transactions if there is a clear pattern of payee and amount that repeat over a regular cadence" — and the stated rule is concretely **"checking if the same payment was made 2 months in a row."** Detected items become **suggested recurring items** on a separate page behind a "Show suggestions" button; they are not added to the Recurring page until approved or rejected. New transactions auto-link to approved recurring items. Detection works from **CSV imports as well as bank syncing**.
Sources: [support.lunchmoney.app/finances/recurring-items/the-basics-of-recurring](https://support.lunchmoney.app/finances/recurring-items/the-basics-of-recurring), [support.lunchmoney.app/finances/recurring-items/recurring-transactions](https://support.lunchmoney.app/finances/recurring-items/recurring-transactions)

**Verdict: Lunch Money is the blueprint; Rocket Money is the feature list.** Lunch Money proves the key point for this architecture: **recurring detection does not require bank aggregation** — it works on imported CSV history, which Money Manager already has. The "2 months in a row, same payee and amount" rule is a `GROUP BY merchant` SQL query, and the suggest-then-approve queue avoids polluting the user's subscription list with false positives. Rocket Money's price-increase and trial-conversion alerts are the natural v2 on top of the same index. *High confidence.*

### 3e. Arabic / MENA and Europe-relevant

This is the weakest-sourced section and the findings are correspondingly hedged.

- **Wally** markets Arabic support and multi-currency tracking aimed at MENA expats, with manual entry plus receipt scanning. Source: [wallybudgeting.app](https://wallybudgeting.app/), [play.google.com/…/wally](https://play.google.com/store/apps/details?id=com.foureyes.studio.wally)
- **Hakbah** (Saudi, 1.2M+ users) is not a budgeting app — it digitizes the **jam'iyyah** (rotating savings circle). Source: [hakbah.sa](https://hakbah.sa/?lang=en)
- **Mod5r** (Saudi, founded 2020) does open-banking multi-account budget/expense/income tracking. Source: [pragmaticcoders.com/blog/11-must-know-open-banking-apps-in-saudi-arabia](https://www.pragmaticcoders.com/blog/11-must-know-open-banking-apps-in-saudi-arabia)
- **Tarabut Gateway** is the region's largest regulated open-banking platform — the aggregation layer a MENA-market version would eventually sit on. Source: same as above.
- I could not find an Arabic-first product whose **RTL financial-chart and number-formatting** decisions are documented well enough to cite. Treat the RTL guidance below as first-principles reasoning, **not** as sourced competitive research.

**Verdict: no direct feature to copy; two strategic observations.** First, "Mala2" did not resolve to a verifiable product — dropping the claim rather than guessing. Second, the interesting MENA-specific *product* idea in this space is the jam'iyyah/ROSCA pattern (Hakbah), which is a genuine cultural primitive with no Western equivalent and which the existing `savings` table could model as a group-goal variant. That is a market-expansion bet, not an MVP gap — flagged here and explicitly **not** recommended for the near-term sequence. *Low confidence on the market read; high confidence that nothing here belongs in the next three months of work.*

---

## 4. Gaps worth closing

Ranked by (user value × architectural fit) ÷ effort.

| # | Opportunity | Why it matters here | Effort | Files touched | Confidence |
|---|---|---|---|---|---|
| G1 | **First-run setup + honest demo data.** Replace `seed()` with a 4-step wizard (income → fixed expenses → debts → target months), and put demo data behind an explicit "explore with sample data" choice that is visibly labelled and one-click erasable. | The app currently opens on a red "your plan needs adjustment" state computed from someone else's double-counted finances. Nothing else you build gets seen through that. | **S** | `server.js:96-113` (seed → `/api/setup`), `app.js` (new `onboarding()` view + `setPage` gate), `index.html` | **High** |
| G2 | **Surface total interest + debt-free date.** `simulate()` already computes per-month `interest` (`server.js:413`) and `debtPlan()` drops it (`server.js:452-457`). Add `totalInterest`, `payoffDate`, `monthsToPayoff` to the response and three cards to the plan page. | The engine's best output is invisible. This is the cheapest credibility win in the product. | **S** | `server.js:432-459`, `app.js:1363-1571` | **High** |
| G3 | **Fix the `toISOString()` month bug.** Use the existing `toLocalDateStr()` at `server.js:453` and `server.js:473`. | Every plan row is labelled with the wrong month in UTC+1/+2. The fix and its rationale are already in the file. | **S** | `server.js:453`, `server.js:473` | **High** |
| G4 | **Snowball vs avalanche comparison.** Parameterize the sort at `server.js:422` (`apr desc` \| `balance asc` \| `priority`), accept `?strategy=`, and add a comparison view showing months-to-payoff and total interest side by side with the delta. | The engine is already 90% there; this is the top feature request pattern across the entire debt-payoff category and is on the README's own post-MVP list. | **S/M** | `server.js:407-460`, `app.js` plan page | **High** |
| G5 | **Rules engine v1.** New `rules` table (`id, priority, field, operator, value, action_field, action_value, active`). Conditions on merchant/notes (contains, is, starts-with), amount (>, <, =), direction. Actions set category, notes, or link a subscription. Apply during `/api/transactions/import-file` and on manual create; add `POST /api/rules/apply` to re-run over history (Firefly's retroactive apply). Rank least-specific-first within priority (Actual's ranking). | Everything is `Uncategorized`. Without categories, the category filter, the spending mix chart, and every future budget feature are inert. Maybe Finance shipped this with three condition types. | **M** | `server.js` (schema + `/api/rules` CRUD + `applyRules()` in `normalizeTransaction` path), `app.js` (rules page + configs entry), `index.html` (nav item) | **High** |
| G6 | **"Learn from my edit" + review queue.** When a user sets a category on a transaction, offer "always categorize <merchant> as <category>?" and write a rule. Add a `direction`/`category=Uncategorized` filter chip and a count badge. Never auto-apply below confidence — leave it `Uncategorized`. | Actual's payee-learning and Copilot's confidence gate, minus the ML. Turns G5 from a feature users must configure into one that configures itself. | **S** (on top of G5) | `app.js` (transaction edit flow), `server.js` `/api/rules` | **High** |
| G7 | **Import mapping + preview + dedupe.** Column-mapping dropdowns, a date-format picker, a "single signed amount column" mode that infers `direction` from sign, a "flip amount" toggle, a preview table, and duplicate detection on (date, amount, merchant). | Today a normal bank CSV with signed amounts and no `direction` column is rejected wholesale on row 2 (`server.js:185`, `:206`, `:246`). This is a hard wall in front of the feature that makes every other feature useful. | **M** | `server.js:233-252`, `app.js:1099-1127`, `index.html` (modal) | **High** |
| G8 | **Variable income & expenses.** Add `amount_min`/`amount_max` to `income` and `expenses`; plan against `amount_min` (or a `planning_amount`) when `type='variable'`; render `~` on approximate figures the way Actual does; show a variable-income buffer figure per YNAB. Also add a schema-migration helper — `CREATE TABLE IF NOT EXISTS` will not add these columns to an existing DB. | `income.type='variable'` exists and is read by exactly nothing (`server.js:433`, `:462`). The feasibility verdict is currently falsely confident for anyone with irregular income. | **M** | `server.js:12-30` + migration fn, `server.js:432-478`, `app.js:737-760` configs | **High** |
| G9 | **Subscription detection from imported statements.** `GROUP BY merchant` over `transactions` looking for the same merchant at a similar amount (±5%) in 2+ consecutive months; emit **suggestions** to a review queue; on approval create the `subscriptions` row and back-link matched transactions via a new `subscription_id` column. | Lunch Money proves this works from CSV alone — no aggregation needed. It turns the manual subscriptions table into the app's most automatic feature and directly serves the free-trial radar that already exists. | **M** | `server.js` (new `detectRecurring()` + `/api/subscriptions/suggestions`), `app.js` subscriptions page | **High** |
| G10 | **Bills calendar + ICS export + due-date centre.** Extend `computeUpcomingBills()` beyond its 7-day default to a month grid; match against `transactions` to colour each item paid / paid-different-amount / upcoming / missed (Monarch's four states); expose `GET /api/bills.ics` so the user's own calendar app does the reminding. | Notifications are the README's stated post-MVP item, and ICS is the only version of it that does not require an account, a job runner, or a cloud service. It also works on iPhone today, before the native app ships. | **M** | `server.js:328-344` + new `/api/bills.ics`, `app.js` (calendar view) | **High** |
| G11 | **Debt milestones + what-if.** Per-debt "paid off in month N", a "next debt cleared" marker on the dashboard, and a what-if slider for extra monthly payment / lump sum that re-runs `simulate()` and shows the date and interest delta live. | The Sankey already establishes the interactive-slider idiom in this codebase (`server.js:488`, `cashflow-sankey.html`) — this reuses a pattern the app already owns. | **M** | `server.js:407-460`, `app.js` plan page | **Medium-high** |
| G12 | **Wire up the dead markup.** `#toast-host`, `#confirm-modal`, `#topbar-add`, `#search-form` all exist in `index.html` and are referenced zero times in `app.js`; replace `alert()`/`confirm()` (`app.js:1118`, `:1335`, `:1347`). | Pure polish, but the HTML, CSS and ARIA are already written and paid for. Native `confirm()` in an RTL Arabic app renders an English-chrome browser dialog. | **S** | `app.js` only | **High** |
| G13 | **Locale/number formatting decision.** `fmt()` hardcodes `Intl.NumberFormat("en-US")` (`app.js:74`) inside a `dir="rtl"` `lang="ar"` document. Make it a setting (`ar-EG` Eastern Arabic numerals / `ar-EG-u-nu-latn` / `en-US`) rather than an accident. | Not obviously a bug — many Arabic-speaking finance users prefer Latin digits — but it should be a decision, and chart axes and the Sankey iframe need the same treatment to stay consistent. | **S** | `app.js:74-79`, `public/cashflow-sankey.html`, `settings` table | **Medium** |
| G14 | **Category taxonomy.** A `categories` table with an Arabic default set, replacing the free-text `category` inputs with a combobox. | Prerequisite for G5 being useful at scale and for any future budget-vs-actual. Deliberately ranked *below* G5 — rules with free-text categories still work, and shipping the taxonomy first delays the payoff. | **M** | `server.js` schema, `app.js:771` and sibling configs | **Medium-high** |

### Mobile-specific call-outs for the iOS app

These are the places where the answer is **materially different** on iOS, and they should feed the SwiftUI plan directly.

- **M1 — Notifications invert the priority order.** On web, due-date reminders are the weakest item in this report (no server, no account, no job runner → ICS export is the ceiling). On iOS they are among the strongest: `UNUserNotificationCenter` with `UNCalendarNotificationTrigger` gives real, scheduled, offline, zero-infrastructure reminders from `expenses.due_day`, `debts.due_day`, `subscriptions.next_charge_date` and — most valuably — `subscriptions.trial_ends_on`. **A free-trial-ending notification is the single feature most likely to make someone keep the app installed, and it is only buildable on mobile.** Schedule at trial_end − 2 days, matching Monarch's 3-day recurring reminder convention. *High confidence.*
- **M2 — Widgets are the mobile equivalent of the dashboard.** Copilot ships eight. The two that map onto this data model with no new schema are "next bill due" and "debt-free date / progress", both of which read straight from `computeUpcomingBills()` and `debtPlan()` equivalents. A Live Activity during the final month of a payoff plan is an obvious fit for the debt-free date. *Medium confidence (design judgment, not sourced).*
- **M3 — Onboarding is more load-bearing, not less.** G1's wizard is the right shape on both platforms, but on iOS it is the app's entire first impression with no README to fall back on, and it should end with the notification permission prompt **contextualized** ("remind me before Netflix's trial converts?") rather than fired on launch.
- **M4 — Statement import is worse on iOS, so detection matters more.** File-picking a bank CSV on iPhone is painful. That raises the relative value of G9 (subscription detection) and lowers G7's mobile priority — and it argues for the iOS app treating manual quick-add as the primary entry path, with import as a one-time bootstrap (ideally done on the web app and synced).
- **M5 — Sync is the unresolved architectural question.** Web app = SQLite on one machine; iOS app = SwiftData on the phone. Two local-first stores with no sync layer is two products. Actual's answer — CRDT with hybrid logical clocks over a Merkle trie, client-side encrypted so the server never sees plaintext ([github.com/actualbudget/actual](https://github.com/actualbudget/actual)) — is the architecturally correct reference and is a **large** program. The honest interim answer is a signed export/import file, and this should be an explicit decision rather than a drift. *High confidence that it needs deciding; no recommendation on which way.*
- **M6 — RTL is cheaper on iOS.** SwiftUI's automatic layout mirroring plus `FormatStyle`/`Locale` handles most of what `app.js` currently hardcodes. G13's locale decision should be made once and shared as a product rule across both apps; on iOS it is `Locale.current` plus a user override, not a formatter rewrite.

---

## 5. Deliberately not recommended

**N1. Bank aggregation (Plaid / TrueLayer / Tink / Tarabut).** *High confidence.*
Every competitor whose categorization and detection you admire — Copilot, Monarch, Rocket Money — depends on it, and it is tempting to conclude it is the precondition. It is not. Lunch Money explicitly detects recurring items from **CSV imports** as well as syncing ([support.lunchmoney.app](https://support.lunchmoney.app/finances/recurring-items/the-basics-of-recurring)), which means G9 is buildable today. Aggregation would add: a per-user cost, PSD2/SCA compliance, credential custody, an account system, and a permanent cloud dependency in a product whose stated advantage is that the data never leaves the machine. If it is ever done, it is a program with its own budget, not a sprint item. The README's "Supabase/Postgres" line is the beginning of this slope and should be scrutinized on the same grounds.

**N2. A per-user ML categorization model (Copilot-style).** *High confidence.*
Copilot's model needs 30 reviewed transactions before it activates and uses card-identity as a feature — Money Manager has one free-text `account` column and users who may import a few hundred rows total. A deterministic rules engine plus Actual's "most common category for this payee" learning gets most of the accuracy, is explainable, is debuggable, and needs no training infrastructure. Revisit only if rule-coverage measurably plateaus.

**N3. Full YNAB-style zero-based envelope budgeting.** *High confidence.*
The most-requested-sounding feature in the category and the wrong one here. The app's model is income → fixed obligations → debt payoff, and its center of gravity is the payoff plan. Envelope budgeting is a different mental model that would compete with the plan rather than support it, and it demands daily engagement that a debt-payoff tool does not. Take YNAB's *irregular-income principle* (G8); leave the envelopes.

**N4. Migrating the frontend to React/Vue/Svelte.** *High confidence.*
`app.js` is 1,599 lines of template-literal rendering with a `configs` object that already generates every list and form from a declarative spec (`app.js:737-839`). That pattern will carry the rules page, the onboarding wizard, the bills calendar and the import mapper without a build step. A framework migration would consume the entire next cycle and deliver zero user-visible value. The real structural debt is that `app.js` is one file — split it into modules loaded with `<script type="module">`, which needs no bundler. If a rewrite is ever argued for, it should be argued for on its own, against the iOS app's existence, not smuggled in behind a feature.

**N5. Firefly III's full rule surface.** *High confidence.*
40+ triggers across seven categories, strict/non-strict, NOT-inversion, stop-processing at three levels, and an expression engine. That is the accreted result of years of individual requests, and reproducing it would produce a rules UI more complicated than the app it sits in. Maybe Finance's three condition filters are the honest v1 target.

**N6. Cloud push notifications / email reminders (web).** *High confidence.*
Requires a job runner (Firefly III's recurring transactions and notifications both **require cron** — [docs.firefly-iii.org/…/cron](https://docs.firefly-iii.org/how-to/firefly-iii/advanced/cron/)), a delivery identity, and therefore an account. For a single-user local app this is a large infrastructure and privacy cost for something ICS export (G10) and iOS local notifications (M1) deliver better. Web Push with a service worker is a *possible* middle path but only fires when the browser is running and adds a service worker to an app with no offline story — not worth it yet.

**N7. Multi-currency.** *Medium confidence.*
On the README's post-MVP list, and it is real work: `€` is hardcoded in the Sankey payload (`server.js:518`, `:601`), `fmt()` hardcodes EUR (`app.js:76`), and doing it properly means per-transaction currency, rate storage, historical rates, and a display-currency conversion layer. The user is EUR-resident with EUR debts. Defer until there is a second currency actually in play. (If the iOS app targets MENA users first, this inverts — flag it as an iOS-scoping question.)

**N8. Receipt OCR / photo capture.** *Medium confidence.*
Wally markets it and it demos well. The `documents` table is metadata-only today (no file storage, no upload endpoint), so this means a storage layer, an OCR dependency, and an Arabic-capable OCR model — a poor trade against G5/G9, which improve data quality for every existing row rather than adding a new capture path. On iOS, VisionKit makes this dramatically cheaper and it is worth revisiting there **after** the core gaps close.

**N9. Jam'iyyah / ROSCA group savings (Hakbah pattern).** *Low confidence — flagged, not rejected on the merits.*
Genuinely interesting, genuinely MENA-native, with 1.2M+ users demonstrating demand ([hakbah.sa](https://hakbah.sa/?lang=en)), and the `savings` table could model it. But it is inherently multi-party, which collides with single-user-no-auth at the deepest level, and it is a market-expansion bet rather than a gap in the current product. Recorded here so it is not rediscovered as a surprise; not recommended for the next two quarters.

**N10. Anything requiring a schema migration framework — until G8 forces it.** *High confidence.*
Worth stating explicitly: `server.js:12-94` uses `CREATE TABLE IF NOT EXISTS` with no `PRAGMA user_version` and no migration runner. Several recommendations above add columns to existing tables, and on any DB that already exists those `CREATE TABLE` statements are no-ops — the columns will silently not appear. **A ~30-line `user_version`-based migration runner is a hard prerequisite for G5, G8, G9 and G14, and should land in the same PR as the first of them.** This is the most likely way the sequence below goes wrong in practice.

---

## 6. Suggested sequence

### Phase 0 — Foundations (days, not weeks)
1. **G3** — fix the `toISOString()` month bug (two lines, existing helper).
2. **N10** — `PRAGMA user_version` migration runner. Unblocks everything schema-touching below.
3. **G2** — surface `totalInterest`, `payoffDate`, `monthsToPayoff`. The data is already computed and discarded.
4. **G12** — wire up the toast host and confirm modal that are already in the HTML.

*Unblocks:* every later phase, and produces a visibly better plan page in the first week.

### Phase 1 — Make the first five minutes work (highest leverage in the report)
5. **G1** — first-run wizard; demo data becomes opt-in and labelled. Fixes the red-failure-state opening.
6. **G4** — snowball/avalanche comparison. Builds directly on G2 and turns the app's strongest engine into its strongest story.

*Unblocks:* honest user testing. Until G1 ships you cannot tell whether anyone understands the product or is just reacting to the seeded crisis. **Do not skip ahead of this.**

### Phase 2 — Make the data mean something
7. **G7** — import mapping, preview, signed-amount mode, dedupe. This is the gate: rules and detection are worthless if real statements will not load.
8. **G5** — rules engine v1 (three condition types, applied on import, re-runnable over history).
9. **G6** — learn-from-edit prompt + review queue + confidence gate.
10. **G14** — category taxonomy, once rules have proven which categories people actually reach for.

*Unblocks:* G9, the spending-mix chart becoming truthful, the category filter becoming useful, and any future budget-vs-actual work. This is the phase that changes what the product *is*.

### Phase 3 — Reality over assumptions
11. **G8** — variable income/expenses; plan conservatively; `~` on approximate figures.
12. **G9** — subscription detection from imported history with a suggest-and-approve queue.
13. **G10** — bills calendar with Monarch's four states, plus `/api/bills.ics`.

*Unblocks:* the free-trial radar becoming automatic rather than manual, and the feasibility verdict becoming trustworthy for irregular earners.

### Phase 4 — Depth and polish
14. **G11** — milestones and what-if sliders.
15. **G13** — the locale/numerals decision, applied consistently across app, charts and Sankey.

### iOS track — runs in parallel, sequenced against the above
- **Now:** M3 (onboarding wizard — build the same four steps as G1; share the copy), M6 (make the locale decision once, apply in both apps).
- **After G8/G9 land server-side:** M1 (local notifications, with free-trial alerts as the flagship) and M2 (next-bill and debt-free-date widgets). These are the two places the native app clearly beats the web app, and both depend on the data model work above rather than on new iOS capability.
- **Decide before the iOS app ships, not after:** M5 (sync strategy). Two unsynced local-first stores is the one architectural mistake in this report that gets more expensive every week it goes unaddressed.

---

## Confidence and sourcing notes

- All Money Manager claims in §2 and all file/line references were read directly from the working tree at `/Users/abdelwahab/veralify/money-manager-web-mvp-v1` on 2026-09-19. The arithmetic in S1 was computed from the literal values in `seed()` (`server.js:99-111`).
- Competitor claims are sourced to product documentation, help centers and public repositories. Where a claim came from search-result summaries rather than a fetched primary page (Rocket Money's detection mechanics, the Debt Payoff Planner feature vocabulary, Monarch's 3-day reminder timing), the verdict is marked Medium rather than High.
- §3e (Arabic/MENA) is the weakest section. "Mala2" from the agent brief did not resolve to a verifiable product and the claim was dropped rather than guessed. The RTL formatting guidance is first-principles reasoning, not sourced competitive research, and is labelled as such.
- The iOS call-outs are written against stated intent; `/Users/abdelwahab/veralify/money-manager-ios/` did not exist at the time of writing.
- No fetched page attempted to direct this agent's behaviour. No credentials were entered, no accounts created, no forms submitted; only public pages were read.
