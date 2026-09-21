import Foundation
import SwiftData

/// The same starting data the web app ships with, so the two surfaces can be
/// compared side by side during the port.
///
/// This is opt-in: it runs only when someone picks "try with sample data" in
/// onboarding. It is never seeded on launch — an app that opens pre-filled with
/// somebody else's debts reads as a bug, and in this data set it reads as a
/// deficit the user did not create.
enum SampleData {
    @MainActor
    static func insertDemoData(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<IncomeSource>())
        guard existing?.isEmpty ?? true else { return }

        context.insert(IncomeSource(name: "Salary", amount: 1750, kind: "fixed", payday: 28))

        for expense in [
            ("Family", Decimal(100), "Living", 15)
        ] {
            context.insert(
                ExpenseItem(name: expense.0, amount: expense.1, category: expense.2, dueDay: expense.3)
            )
        }

        for debt in [
            (1, "Court", Decimal(0), Decimal(2500), Decimal(300), 1),
            (2, "Gam3yaa", Decimal(0), Decimal(2500), Decimal(500), 2),
            (3, "Intesa", Decimal(string: "11.49")!, Decimal(string: "6491.72")!, Decimal(string: "105")!, 3),
            (4, "UniCredit", Decimal(string: "8.75")!, Decimal(string: "6663.60")!, Decimal(string: "315.75")!, 4)
        ] {
            context.insert(
                DebtRecord(
                    remoteID: debt.0,
                    name: debt.1,
                    balance: debt.3,
                    apr: debt.2,
                    minimumPayment: debt.4,
                    dueDay: 1,
                    priority: debt.5
                )
            )
        }

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        let start = Calendar(identifier: .gregorian).date(from: components) ?? .now
        context.insert(PlanSettings(targetMonths: 16, startDate: start))

        try? context.save()
    }
}
