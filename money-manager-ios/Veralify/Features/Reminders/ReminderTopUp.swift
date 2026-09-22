import SwiftUI
import SwiftData

/// Keeps the notification queue matching the data.
///
/// Local notifications are queued ahead, which means a queue can go stale: a due
/// date the user changed, a debt they cleared, or simply three months passing.
/// This re-arms it when the app comes back to the front and whenever any figure
/// a reminder mentions actually changes.
///
/// Carries no appearance of its own — it is attached as a background so it can
/// hold the queries without occupying any layout.
struct ReminderTopUp: View {
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query private var payments: [DebtPayment]

    @Environment(\.scenePhase) private var scenePhase
    @State private var notifications = NotificationManager()

    /// Everything a reminder's text or timing depends on. Anything else about a
    /// debt can change without the queue needing rebuilding.
    private var digest: String {
        let debtParts = debts.map { "d\($0.remoteID):\($0.dueDay ?? -1):\($0.minimumPayment):\($0.name)" }
        let expenseParts = expenses.filter(\.isActive).map { "e\($0.name):\($0.dueDay ?? -1):\($0.amount)" }
        let paymentParts = payments.filter { !$0.isPaid }.map { "p\($0.debtRemoteID):\($0.date.timeIntervalSince1970):\($0.amount)" }
        return (debtParts + expenseParts + paymentParts).joined(separator: "|")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .task {
                await notifications.refreshPermission()
                await reschedule()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await notifications.refreshPermission()
                    await reschedule()
                }
            }
            .onChange(of: digest) { _, _ in
                Task { await reschedule() }
            }
    }

    private func reschedule() async {
        await PaymentReminders.reschedule(
            debts: debts,
            expenses: expenses,
            payments: payments,
            permission: notifications.permission
        )
    }
}
