import SwiftUI
import SwiftData

@main
struct VeralifyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: DebtRecord.self, IncomeSource.self, ExpenseItem.self, PlanSettings.self,
                TransactionRecord.self, QuestCompletion.self,
                DebtPayment.self, MonthlySnapshot.self,
                FamilyMember.self, FamilyExpense.self, FamilySettlement.self
            )
        } catch {
            // A store that cannot open is unrecoverable and silently showing an
            // empty app would look like data loss, so fail loudly in debug.
            fatalError("Could not open the Veralify store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
