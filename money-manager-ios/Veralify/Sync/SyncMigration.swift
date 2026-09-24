import Foundation
import SwiftData
import VeralifyCore

/// One-time fix-ups for a store written before sync existed. Runs at launch,
/// before any screen reads the store.
enum SyncMigration {
    private static let doneKey = "sync.migration.v1"

    @MainActor
    static func runIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        do {
            try repairIDs(IncomeSource.self, in: context)
            try repairIDs(IncomeActual.self, in: context)
            try repairIDs(ExpenseItem.self, in: context)
            try repairIDs(DebtRecord.self, in: context)
            try repairIDs(DebtPayment.self, in: context)
            try repairIDs(PlanSettings.self, in: context)
            try repairIDs(TransactionRecord.self, in: context)
            try repairIDs(MoneyLoss.self, in: context)
            try repairIDs(MonthlySnapshot.self, in: context)
            try repairIDs(CategoryBudget.self, in: context)

            // Every entry in the store predates the currency column, which
            // migrated as "EUR". The amounts were typed in whatever currency
            // the app was showing, so that is the better guess.
            let currency = AppSettings.currencyCode
            for entry in try context.fetch(FetchDescriptor<TransactionRecord>()) where entry.currency != currency {
                entry.currency = currency
            }

            try migrateCategoriesToKeys(in: context)

            try context.save()
            UserDefaults.standard.set(true, forKey: doneKey)
        } catch {
            // Left unset, so it is tried again on the next launch. Sync pushes
            // nothing until the ids are unique: see `SyncEngine.runOnce`.
            assertionFailure("Sync migration failed: \(error)")
        }
    }

    /// Whether the fix-ups have run, so a sync never pushes rows that still
    /// share a migrated id.
    static var isComplete: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// Rewrites categories stored under the old preset names ("Food",
    /// "General") to the shared keys (`groceries`, `other`), which is what
    /// receipts, the web and budgets file by (contracts §3).
    ///
    /// Two budgets can land on one key ("General" and "Uncategorized" are both
    /// `other`); the category is unique, so they become one, keeping the
    /// higher limit rather than silently dropping one of them.
    @MainActor
    private static func migrateCategoriesToKeys(in context: ModelContext) throws {
        for entry in try context.fetch(FetchDescriptor<TransactionRecord>()) {
            let key = CategoryKeys.key(forLocal: entry.category)
            if entry.category != key { entry.category = key }
        }

        var byKey: [String: CategoryBudget] = [:]
        let budgets = try context.fetch(FetchDescriptor<CategoryBudget>(sortBy: [SortDescriptor(\.createdAt)]))
        for budget in budgets {
            let key = CategoryKeys.key(forLocal: budget.category)
            if let kept = byKey[key] {
                kept.limit = max(kept.limit, budget.limit)
                context.delete(budget)
            } else {
                byKey[key] = budget
            }
        }
        // Renamed only once the duplicates are gone, so no two rows ever
        // share a category and trip the unique constraint.
        for (key, budget) in byKey where budget.category != key {
            budget.category = key
        }
    }

    /// Gives every row that shares an id with an earlier one a fresh id — see
    /// `SyncIdentity.duplicatePositions` for why they share one.
    @MainActor
    private static func repairIDs<M: SyncedModel>(_ type: M.Type, in context: ModelContext) throws {
        let models = try context.fetch(FetchDescriptor<M>())
        for position in SyncIdentity.duplicatePositions(in: models.map(\.id)) {
            models[position].id = UUID()
            models[position].needsPush = true
        }
    }
}
