import Foundation
import SwiftData
import SwiftUI

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

    var direction: EntryDirection {
        get { EntryDirection(rawValue: directionRaw) ?? .debit }
        set { directionRaw = newValue.rawValue }
    }

    var scope: EntryScope {
        get { EntryScope(rawValue: scopeRaw) ?? .personal }
        set { scopeRaw = newValue.rawValue }
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
        category: String = "General",
        account: String = "Cash",
        notes: String = "",
        createdAt: Date = .now
    ) {
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
    static let categories = ["General", "Tools", "Food", "Transport", "Bills", "Shopping", "Health"]
    static let accounts = ["Cash", "Credit Card", "Bank", "Savings"]
}
