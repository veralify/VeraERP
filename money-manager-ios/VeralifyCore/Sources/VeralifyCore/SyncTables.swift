import Foundation

/// The synced `money_*` tables, in dependency order (contracts §2).
///
/// Declaration order is pull and push order: a parent always lands before the
/// rows that point at it, so a debt exists before its payments and an income
/// before its logged months.
public enum SyncTable: String, CaseIterable, Sendable {
    case categories = "money_categories"
    case merchantRules = "money_merchant_rules"
    case settings = "money_settings"
    case income = "money_income"
    case incomeActuals = "money_income_actuals"
    case expenses = "money_expenses"
    case debts = "money_debts"
    case debtPayments = "money_debt_payments"
    /// Pull only: receipt capture's upload queue writes these rows itself,
    /// through the few columns the client may write (contracts §2).
    case receipts = "money_receipts"
    case transactions = "money_transactions"
    case losses = "money_losses"
    case snapshots = "money_monthly_snapshots"
    case budgets = "money_budgets"

    /// Rows per pull page (contracts §2).
    public static let pageSize = 500

    /// The data columns the app owns, excluding `id`, `user_id` and the
    /// server-managed ones. Exactly the keys an encoded row carries besides
    /// `id`, `user_id` and `deleted_at`.
    public var columns: [String] {
        switch self {
        case .categories: ["key", "name", "icon", "color", "kind", "sort_order", "archived"]
        case .merchantRules: ["merchant_key", "category_key", "scope", "hits"]
        case .settings: ["key", "value"]
        case .income: ["name", "amount", "type", "payday", "active"]
        case .incomeActuals: ["income_id", "month", "amount"]
        case .expenses: ["name", "amount", "category", "due_day", "active"]
        case .debts: ["name", "balance", "apr", "minimum_payment", "due_day", "priority", "local_id", "extra_payment"]
        case .debtPayments:
            ["debt_id", "amount", "interest_portion", "applied_amount", "paid_on", "is_paid",
             "is_early_payoff", "previous_minimum", "new_minimum", "note"]
        case .transactions:
            ["transaction_date", "occurred_at", "merchant", "amount", "direction", "category", "account",
             "notes", "currency", "tax_amount", "scope", "source", "receipt_id"]
        case .losses: ["occurred_on", "amount", "reason", "note"]
        case .receipts: ["image_paths", "source", "status", "extraction", "transaction_id"]
        case .snapshots: ["month", "income", "expenses", "debt_minimums", "debt_balance"]
        case .budgets: ["category_key", "monthly_limit"]
        }
    }

    /// Postgres `numeric` columns. Pulled with a `::text` cast so a figure
    /// arrives as its exact decimal text rather than a JSON number that a
    /// decoder may read through a `Double`.
    public var numericColumns: Set<String> {
        switch self {
        case .income, .expenses, .incomeActuals, .losses: ["amount"]
        case .debts: ["balance", "apr", "minimum_payment", "extra_payment"]
        case .debtPayments: ["amount", "interest_portion", "applied_amount", "previous_minimum", "new_minimum"]
        case .transactions: ["amount", "tax_amount"]
        case .snapshots: ["income", "expenses", "debt_minimums", "debt_balance"]
        case .budgets: ["monthly_limit"]
        case .categories, .merchantRules, .settings, .receipts: []
        }
    }

    /// Columns pulled as text: the numeric ones, and `money_receipts.extraction`,
    /// whose JSON is kept verbatim on the phone rather than taken apart here.
    public var textColumns: Set<String> {
        self == .receipts ? numericColumns.union(["extraction"]) : numericColumns
    }

    /// Tables this engine only reads.
    public var isPullOnly: Bool { self == .receipts }

    /// `money_settings` is keyed by `(user_id, key)` and has no `id`.
    public var hasID: Bool { self != .settings }

    /// The upsert's `on_conflict` target.
    public var conflictTarget: String { hasID ? "id" : "user_id,key" }

    /// The PostgREST `select` for a pull.
    public var selectList: String {
        var names = hasID ? ["id"] : []
        names += columns.map { textColumns.contains($0) ? "\($0)::text" : $0 }
        names += hasID ? ["deleted_at", "created_at", "updated_at", "sync_seq"] : ["deleted_at", "updated_at", "sync_seq"]
        return names.joined(separator: ",")
    }
}

/// Server bookkeeping that arrives with every pulled row.
public struct SyncMeta: Sendable, Equatable {
    /// The row id, or for `money_settings` the setting's key.
    public let id: String
    public let syncSeq: Int64
    public let updatedAt: Date?
    public let createdAt: Date?
    public let deletedAt: Date?

    public var isDeleted: Bool { deletedAt != nil }

    public init(row: SyncRow, table: SyncTable) throws {
        let reader = SyncRowReader(row)
        id = table.hasID ? try reader.uuid("id").uuidString.lowercased() : try reader.string("key")
        syncSeq = try reader.int64("sync_seq")
        updatedAt = try reader.optionalInstant("updated_at")
        createdAt = try reader.optionalInstant("created_at")
        deletedAt = try reader.optionalInstant("deleted_at")
    }
}

public struct SyncDecodeError: Error, Equatable, CustomStringConvertible {
    public let column: String
    public let reason: String
    public var description: String { "\(column): \(reason)" }
}

/// Typed access to a pulled row, failing loudly on a wrong or missing value
/// rather than defaulting it — a default here would be written back to the
/// server on the next push and overwrite the real figure.
public struct SyncRowReader {
    let row: SyncRow

    public init(_ row: SyncRow) { self.row = row }

    private func fail(_ column: String, _ reason: String) -> SyncDecodeError {
        SyncDecodeError(column: column, reason: reason)
    }

    private func value(_ column: String) -> SyncValue {
        row[column] ?? .null
    }

    public func string(_ column: String) throws -> String {
        guard let text = value(column).stringValue else { throw fail(column, "expected text") }
        return text
    }

    public func optionalString(_ column: String) throws -> String? {
        value(column).isNull ? nil : try string(column)
    }

    public func uuid(_ column: String) throws -> UUID {
        guard let id = UUID(uuidString: try string(column)) else { throw fail(column, "expected a UUID") }
        return id
    }

    public func strings(_ column: String) throws -> [String] {
        switch value(column) {
        case .strings(let list): return list
        case .null: return []
        default: throw fail(column, "expected a list of text")
        }
    }

    public func optionalUUID(_ column: String) throws -> UUID? {
        value(column).isNull ? nil : try uuid(column)
    }

    public func decimal(_ column: String) throws -> Decimal {
        guard let amount = SyncFormat.decimal(from: try string(column)) else { throw fail(column, "expected a decimal") }
        return amount
    }

    public func optionalDecimal(_ column: String) throws -> Decimal? {
        value(column).isNull ? nil : try decimal(column)
    }

    public func int64(_ column: String) throws -> Int64 {
        switch value(column) {
        case .int(let number): return number
        // bigint can arrive as text from some proxies; accept exact digits only.
        case .string(let text): if let number = Int64(text) { return number }
        default: break
        }
        throw fail(column, "expected an integer")
    }

    public func int(_ column: String) throws -> Int {
        Int(try int64(column))
    }

    public func optionalInt(_ column: String) throws -> Int? {
        value(column).isNull ? nil : try int(column)
    }

    public func bool(_ column: String) throws -> Bool {
        guard let flag = value(column).boolValue else { throw fail(column, "expected a boolean") }
        return flag
    }

    public func calendarDate(_ column: String, calendar: Calendar) throws -> Date {
        guard let date = SyncFormat.date(fromCalendarDate: try string(column), calendar: calendar)
        else { throw fail(column, "expected YYYY-MM-DD") }
        return date
    }

    public func instant(_ column: String) throws -> Date {
        guard let date = SyncFormat.date(fromInstant: try string(column)) else { throw fail(column, "expected an ISO 8601 instant") }
        return date
    }

    public func optionalInstant(_ column: String) throws -> Date? {
        value(column).isNull ? nil : try instant(column)
    }
}

// MARK: - Encoding helpers

extension SyncValue {
    static func text(_ value: String?) -> SyncValue { value.map(SyncValue.string) ?? .null }
    static func money(_ value: Decimal?) -> SyncValue { value.map { .string(SyncFormat.decimalString($0)) } ?? .null }
    static func number(_ value: Int?) -> SyncValue { value.map { .int(Int64($0)) } ?? .null }
    static func uuid(_ value: UUID?) -> SyncValue { value.map { .string($0.uuidString.lowercased()) } ?? .null }
}

/// The columns every row with an id carries on a push.
private func baseRow(id: UUID, userID: UUID) -> SyncRow {
    // `deleted_at` is sent as null on every live row: pushing a row is a
    // statement that it exists, so a row deleted elsewhere and then edited
    // here comes back — the later write wins (contracts §2).
    ["id": .uuid(id), "user_id": .uuid(userID), "deleted_at": .null]
}

// MARK: - Rows

public struct IncomeRow: Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var amount: Decimal
    /// `IncomeKind` raw value — the server's `type` uses the same words.
    public var kind: String
    public var payday: Int?
    public var isActive: Bool

    public init(id: UUID, name: String, amount: Decimal, kind: String, payday: Int?, isActive: Bool) {
        self.id = id; self.name = name; self.amount = amount; self.kind = kind; self.payday = payday; self.isActive = isActive
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        let type = try r.string("type")
        self.init(
            id: try r.uuid("id"), name: try r.string("name"), amount: try r.decimal("amount"),
            kind: IncomeKind(rawValue: type)?.rawValue ?? IncomeKind.fixed.rawValue,
            payday: try r.optionalInt("payday"), isActive: try r.bool("active")
        )
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "name": .string(name),
            "amount": .money(amount),
            // The server only accepts fixed/variable; anything else a newer
            // build might write reads as fixed, which is what the plan assumes.
            "type": .string(IncomeKind(rawValue: kind)?.rawValue ?? IncomeKind.fixed.rawValue),
            "payday": .number(payday),
            "active": .bool(isActive)
        ]) { $1 }
    }
}

public struct IncomeActualRow: Sendable, Equatable {
    public var id: UUID
    public var incomeID: UUID
    public var month: Date
    public var amount: Decimal

    public init(id: UUID, incomeID: UUID, month: Date, amount: Decimal) {
        self.id = id; self.incomeID = incomeID; self.month = month; self.amount = amount
    }

    public init(row: SyncRow, calendar: Calendar) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), incomeID: try r.uuid("income_id"),
            month: try r.calendarDate("month", calendar: calendar), amount: try r.decimal("amount")
        )
    }

    public func encoded(userID: UUID, calendar: Calendar) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "income_id": .uuid(incomeID),
            "month": .string(SyncFormat.monthDate(month, calendar: calendar)),
            "amount": .money(amount)
        ]) { $1 }
    }
}

public struct ExpenseRow: Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var amount: Decimal
    public var category: String
    public var dueDay: Int?
    public var isActive: Bool

    public init(id: UUID, name: String, amount: Decimal, category: String, dueDay: Int?, isActive: Bool) {
        self.id = id; self.name = name; self.amount = amount; self.category = category; self.dueDay = dueDay; self.isActive = isActive
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), name: try r.string("name"), amount: try r.decimal("amount"),
            category: try r.string("category"), dueDay: try r.optionalInt("due_day"), isActive: try r.bool("active")
        )
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "name": .string(name),
            "amount": .money(amount),
            "category": .string(category),
            "due_day": .number(dueDay),
            "active": .bool(isActive)
        ]) { $1 }
    }
}

public struct DebtRow: Sendable, Equatable {
    public var id: UUID
    /// `DebtRecord.remoteID`. Nil on a debt created on the web, which the
    /// phone numbers on arrival.
    public var localID: Int?
    public var name: String
    public var balance: Decimal
    public var apr: Decimal
    public var minimumPayment: Decimal
    public var extraPayment: Decimal
    public var dueDay: Int?
    public var priority: Int

    public init(
        id: UUID, localID: Int?, name: String, balance: Decimal, apr: Decimal,
        minimumPayment: Decimal, extraPayment: Decimal, dueDay: Int?, priority: Int
    ) {
        self.id = id; self.localID = localID; self.name = name; self.balance = balance; self.apr = apr
        self.minimumPayment = minimumPayment; self.extraPayment = extraPayment; self.dueDay = dueDay; self.priority = priority
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), localID: try r.optionalInt("local_id"), name: try r.string("name"),
            balance: try r.decimal("balance"), apr: try r.decimal("apr"),
            minimumPayment: try r.decimal("minimum_payment"), extraPayment: try r.decimal("extra_payment"),
            dueDay: try r.optionalInt("due_day"), priority: try r.int("priority")
        )
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "local_id": .number(localID),
            "name": .string(name),
            // The server rejects a negative balance or instalment; the phone
            // never means one (a cleared debt is zero), so it is floored rather
            // than letting one bad figure block the whole table's push.
            "balance": .money(max(balance, 0)),
            "apr": .money(max(apr, 0)),
            "minimum_payment": .money(max(minimumPayment, 0)),
            "extra_payment": .money(max(extraPayment, 0)),
            "due_day": .number(dueDay),
            "priority": .number(priority)
        ]) { $1 }
    }
}

public struct DebtPaymentRow: Sendable, Equatable {
    public var id: UUID
    public var debtID: UUID
    public var amount: Decimal
    public var interestPortion: Decimal
    public var appliedAmount: Decimal?
    public var date: Date
    public var isPaid: Bool
    public var isEarlyPayoff: Bool
    public var previousMinimum: Decimal?
    public var newMinimum: Decimal?
    public var note: String

    public init(
        id: UUID, debtID: UUID, amount: Decimal, interestPortion: Decimal, appliedAmount: Decimal?,
        date: Date, isPaid: Bool, isEarlyPayoff: Bool, previousMinimum: Decimal?, newMinimum: Decimal?, note: String
    ) {
        self.id = id; self.debtID = debtID; self.amount = amount; self.interestPortion = interestPortion
        self.appliedAmount = appliedAmount; self.date = date; self.isPaid = isPaid; self.isEarlyPayoff = isEarlyPayoff
        self.previousMinimum = previousMinimum; self.newMinimum = newMinimum; self.note = note
    }

    public init(row: SyncRow, calendar: Calendar) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), debtID: try r.uuid("debt_id"), amount: try r.decimal("amount"),
            interestPortion: try r.decimal("interest_portion"), appliedAmount: try r.optionalDecimal("applied_amount"),
            date: try r.calendarDate("paid_on", calendar: calendar), isPaid: try r.bool("is_paid"),
            isEarlyPayoff: try r.bool("is_early_payoff"), previousMinimum: try r.optionalDecimal("previous_minimum"),
            newMinimum: try r.optionalDecimal("new_minimum"), note: try r.string("note")
        )
    }

    public func encoded(userID: UUID, calendar: Calendar) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "debt_id": .uuid(debtID),
            "amount": .money(amount),
            "interest_portion": .money(interestPortion),
            "applied_amount": .money(appliedAmount),
            "paid_on": .string(SyncFormat.calendarDate(date, calendar: calendar)),
            "is_paid": .bool(isPaid),
            "is_early_payoff": .bool(isEarlyPayoff),
            "previous_minimum": .money(previousMinimum),
            "new_minimum": .money(newMinimum),
            "note": .string(note)
        ]) { $1 }
    }
}

public struct TransactionRow: Sendable, Equatable {
    public var id: UUID
    public var occurredAt: Date
    public var merchant: String
    public var amount: Decimal
    /// Money in. The phone says credit/debit; the server says income/expense.
    public var isCredit: Bool
    /// A `category_key` (contracts §3).
    public var categoryKey: String
    public var account: String
    public var notes: String
    public var currency: String
    public var taxAmount: Decimal?
    /// `personal` or `business`.
    public var scope: String
    /// `manual`, `receipt`, `email`, `import` or `mileage`.
    public var source: String
    public var receiptID: UUID?

    public init(
        id: UUID, occurredAt: Date, merchant: String, amount: Decimal, isCredit: Bool, categoryKey: String,
        account: String, notes: String, currency: String, taxAmount: Decimal?, scope: String, source: String,
        receiptID: UUID?
    ) {
        self.id = id; self.occurredAt = occurredAt; self.merchant = merchant; self.amount = amount
        self.isCredit = isCredit; self.categoryKey = categoryKey; self.account = account; self.notes = notes
        self.currency = currency; self.taxAmount = taxAmount; self.scope = scope; self.source = source
        self.receiptID = receiptID
    }

    public static let scopes: Set<String> = ["personal", "business"]
    public static let sources: Set<String> = ["manual", "receipt", "email", "import", "mileage"]

    public init(row: SyncRow, calendar: Calendar) throws {
        let r = SyncRowReader(row)
        // Rows written before `occurred_at` existed (the web still writes only
        // a date) are placed at midday, so a time-zone difference between the
        // writer and this phone cannot move them to the neighbouring day.
        let occurredAt = try r.optionalInstant("occurred_at")
            ?? r.calendarDate("transaction_date", calendar: calendar).addingTimeInterval(12 * 3600)
        let direction = try r.string("direction")
        self.init(
            id: try r.uuid("id"), occurredAt: occurredAt, merchant: try r.string("merchant"),
            amount: try r.decimal("amount"), isCredit: direction == "income",
            categoryKey: try r.string("category"), account: try r.string("account"), notes: try r.string("notes"),
            currency: try r.string("currency"), taxAmount: try r.optionalDecimal("tax_amount"),
            scope: try r.string("scope"), source: try r.string("source"), receiptID: try r.optionalUUID("receipt_id")
        )
    }

    public func encoded(userID: UUID, calendar: Calendar) -> SyncRow {
        let currencyCode = currency.uppercased()
        return baseRow(id: id, userID: userID).merging([
            "transaction_date": .string(SyncFormat.calendarDate(occurredAt, calendar: calendar)),
            "occurred_at": .string(SyncFormat.instant(occurredAt)),
            "merchant": .string(merchant),
            "amount": .money(max(amount, 0)),
            "direction": .string(isCredit ? "income" : "expense"),
            "category": .string(categoryKey),
            "account": .string(account),
            "notes": .string(notes),
            // Constrained to three capital letters on the server.
            "currency": .string(Self.isCurrencyCode(currencyCode) ? currencyCode : "EUR"),
            "tax_amount": .money(taxAmount.map { max($0, 0) }),
            "scope": .string(Self.scopes.contains(scope) ? scope : "personal"),
            "source": .string(Self.sources.contains(source) ? source : "manual"),
            "receipt_id": .uuid(receiptID)
        ]) { $1 }
    }

    static func isCurrencyCode(_ code: String) -> Bool {
        code.count == 3 && code.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) }
    }
}

public struct LossRow: Sendable, Equatable {
    public var id: UUID
    public var date: Date
    public var amount: Decimal
    public var reason: String
    public var note: String

    public static let reasons: Set<String> = ["lost", "stolen", "fine", "unexpected", "other"]

    public init(id: UUID, date: Date, amount: Decimal, reason: String, note: String) {
        self.id = id; self.date = date; self.amount = amount; self.reason = reason; self.note = note
    }

    public init(row: SyncRow, calendar: Calendar) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), date: try r.calendarDate("occurred_on", calendar: calendar),
            amount: try r.decimal("amount"), reason: try r.string("reason"), note: try r.string("note")
        )
    }

    public func encoded(userID: UUID, calendar: Calendar) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "occurred_on": .string(SyncFormat.calendarDate(date, calendar: calendar)),
            "amount": .money(amount),
            "reason": .string(Self.reasons.contains(reason) ? reason : "other"),
            "note": .string(note)
        ]) { $1 }
    }
}

public struct SnapshotRow: Sendable, Equatable {
    public var id: UUID
    public var month: Date
    public var income: Decimal
    public var expenses: Decimal
    public var debtMinimums: Decimal
    public var debtBalance: Decimal

    public init(id: UUID, month: Date, income: Decimal, expenses: Decimal, debtMinimums: Decimal, debtBalance: Decimal) {
        self.id = id; self.month = month; self.income = income; self.expenses = expenses
        self.debtMinimums = debtMinimums; self.debtBalance = debtBalance
    }

    public init(row: SyncRow, calendar: Calendar) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), month: try r.calendarDate("month", calendar: calendar),
            income: try r.decimal("income"), expenses: try r.decimal("expenses"),
            debtMinimums: try r.decimal("debt_minimums"), debtBalance: try r.decimal("debt_balance")
        )
    }

    public func encoded(userID: UUID, calendar: Calendar) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "month": .string(SyncFormat.monthDate(month, calendar: calendar)),
            "income": .money(income),
            "expenses": .money(expenses),
            "debt_minimums": .money(debtMinimums),
            "debt_balance": .money(debtBalance)
        ]) { $1 }
    }
}

public struct BudgetRow: Sendable, Equatable {
    public var id: UUID
    public var categoryKey: String
    public var monthlyLimit: Decimal

    public init(id: UUID, categoryKey: String, monthlyLimit: Decimal) {
        self.id = id; self.categoryKey = categoryKey; self.monthlyLimit = monthlyLimit
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        self.init(id: try r.uuid("id"), categoryKey: try r.string("category_key"), monthlyLimit: try r.decimal("monthly_limit"))
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "category_key": .string(categoryKey),
            "monthly_limit": .money(monthlyLimit)
        ]) { $1 }
    }
}

public struct CategoryRow: Sendable, Equatable {
    public var id: UUID
    public var key: String
    public var name: String
    public var icon: String?
    public var color: String?
    /// `expense` or `income`.
    public var kind: String
    public var sortOrder: Int
    public var archived: Bool

    public init(id: UUID, key: String, name: String, icon: String?, color: String?, kind: String, sortOrder: Int, archived: Bool) {
        self.id = id; self.key = key; self.name = name; self.icon = icon; self.color = color
        self.kind = kind; self.sortOrder = sortOrder; self.archived = archived
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), key: try r.string("key"), name: try r.string("name"),
            icon: try r.optionalString("icon"), color: try r.optionalString("color"), kind: try r.string("kind"),
            sortOrder: try r.int("sort_order"), archived: try r.bool("archived")
        )
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "key": .string(key),
            "name": .string(name),
            "icon": .text(icon),
            "color": .text(color),
            "kind": .string(kind == "income" ? "income" : "expense"),
            "sort_order": .number(sortOrder),
            "archived": .bool(archived)
        ]) { $1 }
    }
}

public struct MerchantRuleRow: Sendable, Equatable {
    public var id: UUID
    public var merchantKey: String
    public var categoryKey: String
    public var scope: String?
    public var hits: Int

    public init(id: UUID, merchantKey: String, categoryKey: String, scope: String?, hits: Int) {
        self.id = id; self.merchantKey = merchantKey; self.categoryKey = categoryKey; self.scope = scope; self.hits = hits
    }

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        self.init(
            id: try r.uuid("id"), merchantKey: try r.string("merchant_key"), categoryKey: try r.string("category_key"),
            scope: try r.optionalString("scope"), hits: try r.int("hits")
        )
    }

    public func encoded(userID: UUID) -> SyncRow {
        baseRow(id: id, userID: userID).merging([
            "merchant_key": .string(merchantKey),
            "category_key": .string(categoryKey),
            "scope": .text(scope.flatMap { TransactionRow.scopes.contains($0) ? $0 : nil }),
            "hits": .number(max(hits, 1))
        ]) { $1 }
    }
}

/// A pulled `money_receipts` row: what another device captured, or what
/// arrived by e-mail, and the server's progress reading it.
public struct ReceiptRow: Sendable, Equatable {
    public var id: UUID
    /// Storage paths, `{user_id}/{receipt_id}/{page}.jpg`.
    public var imagePaths: [String]
    /// `camera`, `photo_library`, `email` or `web_upload`.
    public var source: String
    /// `uploaded`, `processing`, `extracted`, `confirmed` or `failed`.
    public var status: String
    /// The ReceiptExtraction JSON exactly as the gateway stored it.
    public var extractionJSON: String?
    public var transactionID: UUID?

    public init(row: SyncRow) throws {
        let r = SyncRowReader(row)
        id = try r.uuid("id")
        imagePaths = try r.strings("image_paths")
        source = try r.string("source")
        status = try r.string("status")
        extractionJSON = try r.optionalString("extraction")
        transactionID = try r.optionalUUID("transaction_id")
    }
}

/// `PlanSettings` as the key/value rows of `money_settings`.
///
/// `targetMonths` and `startDate` are the keys the web app already writes, in
/// the same formats, so a plan edited on either surface reads the same on the
/// other.
public struct SettingsRows: Sendable, Equatable {
    public enum Key {
        public static let targetMonths = "targetMonths"
        public static let startDate = "startDate"
        public static let payoffStrategy = "payoffStrategy"
        public static let homeCurrency = "homeCurrency"
        public static let all = [targetMonths, startDate, payoffStrategy, homeCurrency]
    }

    public var targetMonths: Int
    public var startDate: Date
    public var payoffStrategy: String
    public var homeCurrency: String

    public init(targetMonths: Int, startDate: Date, payoffStrategy: String, homeCurrency: String) {
        self.targetMonths = targetMonths; self.startDate = startDate
        self.payoffStrategy = payoffStrategy; self.homeCurrency = homeCurrency
    }

    /// One row per key, as upserted on `(user_id, key)`.
    public func encoded(userID: UUID, calendar: Calendar) -> [String: SyncRow] {
        let values: [String: String] = [
            Key.targetMonths: String(targetMonths),
            Key.startDate: SyncFormat.calendarDate(startDate, calendar: calendar),
            Key.payoffStrategy: payoffStrategy,
            Key.homeCurrency: homeCurrency
        ]
        var rows: [String: SyncRow] = [:]
        for (key, value) in values {
            rows[key] = ["user_id": .uuid(userID), "key": .string(key), "value": .string(value), "deleted_at": .null]
        }
        return rows
    }

    /// Applies one pulled setting. Returns false for a value that does not
    /// parse, which is left alone rather than replaced with a guess — the web
    /// app guards the same way against rows saved before it validated them.
    @discardableResult
    public mutating func apply(key: String, value: String, calendar: Calendar) -> Bool {
        switch key {
        case Key.targetMonths:
            guard let months = Int(value), (1...120).contains(months) else { return false }
            targetMonths = months
        case Key.startDate:
            guard let date = SyncFormat.date(fromCalendarDate: value, calendar: calendar) else { return false }
            startDate = date
        case Key.payoffStrategy:
            guard PayoffStrategy(rawValue: value) != nil else { return false }
            payoffStrategy = value
        case Key.homeCurrency:
            guard TransactionRow.isCurrencyCode(value) else { return false }
            homeCurrency = value
        default:
            return false
        }
        return true
    }
}
