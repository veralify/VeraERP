import SwiftUI
import SwiftData

@main
struct MoneyManagerApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: DebtRecord.self, IncomeSource.self, ExpenseItem.self, PlanSettings.self
            )
        } catch {
            // A store that cannot open is unrecoverable and silently showing an
            // empty app would look like data loss, so fail loudly in debug.
            fatalError("Could not open the Money Manager store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
