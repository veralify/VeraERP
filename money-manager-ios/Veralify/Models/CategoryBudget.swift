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

    /// Sync bookkeeping (contracts §2). Declared with defaults so a store
    /// written before sync existed opens without a mapping model — see
    /// `SyncedModel` for what each one means.
    var id: UUID = UUID()
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?
    var needsPush: Bool = true

    /// `category` holds a category key (contracts §3, e.g. `groceries`) — the
    /// same value that syncs as `category_key`. Budgets written under the old
    /// preset names are rewritten once by `SyncMigration`.
    init(category: String, limit: Decimal, createdAt: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.updatedAt = createdAt
        self.category = category
        self.limit = limit
        self.createdAt = createdAt
    }
}
