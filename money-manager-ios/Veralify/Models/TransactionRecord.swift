import Foundation
import SwiftData
import SwiftUI
import VeralifyCore

/// Which side of the ledger an entry sits on.
enum EntryDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case credit, debit
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .credit: "Money in"
        case .debit:  "Money out"
        }
    }

    var icon: String {
        switch self {
        case .credit: "arrow.down.left"
        case .debit:  "arrow.up.right"
        }
    }

    /// Credits read as gains, debits as losses — the one place in this feature
    /// where colour carries meaning rather than category.
    var accent: Color {
        switch self {
        case .credit: Theme.green
        case .debit:  Theme.red
        }
    }

    var sign: String {
        switch self {
        case .credit: "+"
        case .debit:  "−"
        }
    }
}

/// Business or personal. Kept separate from category so the same category
/// (say "Tools") can exist on both sides without being double counted.
enum EntryScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case business, personal
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .business: "Business"
        case .personal: "Personal"
        }
    }
}

/// Where an entry came from — `money_transactions.source`.
enum EntrySource: String, Codable, CaseIterable, Sendable {
    case manual, receipt, email, `import`, mileage
}

/// A single recorded movement of money.
///
/// Deliberately separate from `IncomeSource` and `ExpenseItem`: those describe
/// the *plan* (what recurs every month and drives the payoff engine), while
/// this is what actually happened. Mixing them would double count.
@Model
final class TransactionRecord {
    var occurredAt: Date
    var name: String
    var amount: Decimal
    private var directionRaw: String
    private var scopeRaw: String
    var category: String
    var account: String
    var notes: String
    var createdAt: Date

    /// ISO code of the currency the amount is in. Declared "EUR" for stores
    /// written before it existed; the first launch after the update sets those
    /// rows to the currency the app was displaying (`SyncMigration`).
    var currency: String = "EUR"
    /// VAT or sales tax included in `amount`, when known (receipt capture).
    var taxAmount: Decimal?
    /// The `money_receipts` row this entry was confirmed from.
    var receiptID: UUID?
    /// `EntrySource` raw value.
    var sourceRaw: String = EntrySource.manual.rawValue

    /// Sync bookkeeping (contracts §2). Declared with defaults so a store
    /// written before sync existed opens without a mapping model — see
    /// `SyncedModel` for what each one means.
    var id: UUID = UUID()
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?
    var needsPush: Bool = true

    var direction: EntryDirection {
        get { EntryDirection(rawValue: directionRaw) ?? .debit }
        set { directionRaw = newValue.rawValue }
    }

    var scope: EntryScope {
        get { EntryScope(rawValue: scopeRaw) ?? .personal }
        set { scopeRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Positive for credits, negative for debits — for summing a balance.
    var signedAmount: Decimal {
        direction == .credit ? amount : -amount
    }

    init(
        occurredAt: Date = .now,
        name: String,
        amount: Decimal,
        direction: EntryDirection,
        scope: EntryScope = .personal,
        category: String = "other",
        account: String = "Cash",
        notes: String = "",
        createdAt: Date = .now,
        currency: String = AppSettings.currencyCode,
        taxAmount: Decimal? = nil,
        receiptID: UUID? = nil,
        source: EntrySource = .manual,
        id: UUID = UUID()
    ) {
        self.id = id
        self.updatedAt = createdAt
        self.currency = currency
        self.taxAmount = taxAmount
        self.receiptID = receiptID
        self.sourceRaw = source.rawValue
        self.occurredAt = occurredAt
        self.name = name
        self.amount = amount
        self.directionRaw = direction.rawValue
        self.scopeRaw = scope.rawValue
        self.category = category
        self.account = account
        self.notes = notes
        self.createdAt = createdAt
    }
}

/// Preset chips offered in the quick-add sheet. Free text stays possible via
/// the entry's own fields; these just make the common cases one tap.
enum EntryPresets {
    /// Category keys (contracts §3) — what `TransactionRecord.category` and
    /// `CategoryBudget.category` hold. These are the keys the original chips
    /// (General, Tools, Food, Transport, Bills, Shopping, Health) map to, in
    /// the same order, so each keeps the colour `CategoryStyle` gives it by
    /// position.
    static let categories = ["other", "office_supplies", "groceries", "transport", "utilities", "shopping", "health"]
    static let accounts = ["Cash", "Credit Card", "Bank", "Savings"]

    /// The localised name to show for a stored category: one of the shared
    /// keys, a custom key from another device, or a legacy name an older
    /// build wrote. Display only — never store it.
    static func title(for category: String) -> String {
        ReceiptCategories.title(for: CategoryKeys.key(forLocal: category))
    }

    /// The SF Symbol for a stored category, however it is spelled.
    static func icon(for category: String) -> String {
        ReceiptCategories.icon(for: CategoryKeys.key(forLocal: category))
    }
}
