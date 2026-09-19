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
        SampleData.seedIfEmpty(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DashboardView()
            }
            .tint(Theme.lime)
            // The design is dark-only: its accents are light, saturated tones
            // that carry near-black text and have no light-mode counterpart yet.
            .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
