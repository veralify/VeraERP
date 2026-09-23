import Foundation
import SwiftData

/// A monthly spending limit for one category.
///
/// Deliberately not part of the plan. `IncomeSource` and `ExpenseItem` say what
/// the household is committed to and drive the payoff engine; this says what the
/// user would *like* to keep one kind of spending under, and it is measured
/// against the ledger. Nothing here can move a debt schedule.
///
/// Unique on the category, because two limits on the same category is not a
/// state with a sensible meaning — the second would silently win.
@Model
final class CategoryBudget {
    @Attribute(.unique) var category: String
    var limit: Decimal
    var createdAt: Date

    init(category: String, limit: Decimal, createdAt: Date = .now) {
        self.category = category
        self.limit = limit
        self.createdAt = createdAt
    }
}
