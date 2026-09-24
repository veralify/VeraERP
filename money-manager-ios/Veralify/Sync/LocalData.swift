import Foundation
import SwiftData
import UserNotifications

/// Removing data from the phone, for signing out and for deleting the account.
enum LocalData {
    /// Removes every synced record and the sync ledger. The account still has
    /// all of it; this is the phone letting go of its copy.
    ///
    /// The ledger goes in the same save as the records. Kept on its own, it
    /// would read every row as deleted here and soft-delete the whole account
    /// on the next sync.
    @MainActor
    static func removeSyncedData(in context: ModelContext) throws {
        try removeAll(IncomeActual.self, in: context)
        try removeAll(IncomeSource.self, in: context)
        try removeAll(ExpenseItem.self, in: context)
        try removeAll(DebtPayment.self, in: context)
        try removeAll(DebtRecord.self, in: context)
        try removeAll(PlanSettings.self, in: context)
        try removeAll(TransactionRecord.self, in: context)
        try removeAll(MoneyLoss.self, in: context)
        try removeAll(MonthlySnapshot.self, in: context)
        try removeAll(CategoryBudget.self, in: context)
        try removeAll(MoneyCategory.self, in: context)
        try removeAll(MerchantRule.self, in: context)
        try removeAll(ReceiptRecord.self, in: context)
        // The receipt photos kept beside the store, one folder per receipt.
        try? FileManager.default.removeItem(at: ReceiptImageStore.root)
        try removeAll(SyncStateRecord.self, in: context)
        // Where the board placed each debt's bubble, keyed by debt number.
        UserDefaults.standard.removeObject(forKey: "boardPositions")
    }

    /// Removes everything the app stores, synced or not, and every scheduled
    /// reminder — for an account that no longer exists.
    ///
    /// The document vault, family splits and quest history never leave the
    /// phone, so after an account deletion nothing else would ever clear them.
    @MainActor
    static func removeEverything(in context: ModelContext) throws {
        try removeSyncedData(in: context)
        try removeAll(QuestCompletion.self, in: context)
        try removeAll(FamilyMember.self, in: context)
        try removeAll(FamilyExpense.self, in: context)
        try removeAll(FamilySettlement.self, in: context)
        try removeAll(StoredDocument.self, in: context)
        try context.save()

        // Reminders outlive the rows they describe; see AccountView's reset.
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
    }

    /// Removes the bill and payment reminders, which name debts and amounts
    /// that are no longer on the phone after signing out. Document-expiry
    /// reminders stay with the documents, which stay too.
    ///
    /// "money." is `PaymentReminders`' identifier prefix for everything it
    /// schedules.
    static func removeMoneyReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("money.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix("money.") }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    /// Fetch-and-delete rather than a batch delete, so SwiftData runs the
    /// cascade rules (an income's logged months) the same way a screen would.
    @MainActor
    private static func removeAll<M: PersistentModel>(_ type: M.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<M>()) {
            context.delete(model)
        }
    }
}
