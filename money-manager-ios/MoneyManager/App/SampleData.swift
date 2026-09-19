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

        context.insert(IncomeSource(name: "Salary", amount: 1600, kind: "fixed", payday: 28))

        for expense in [
            ("Intesa San Paolo", Decimal(178), "Debt / installment", 1),
            ("UniCredit", Decimal(316), "Debt / installment", 1),
            ("Maria", Decimal(500), "Family", 5),
            ("Family", Decimal(200), "Living", 15)
        ] {
            context.insert(
                ExpenseItem(name: expense.0, amount: expense.1, category: expense.2, dueDay: expense.3)
            )
        }

        for debt in [
            (1, "Court", Decimal(0), Decimal(3000), Decimal(500), 1),
            (2, "Intesa", Decimal(string: "11.49")!, Decimal(string: "6491.72")!, Decimal(string: "177.98")!, 2),
            (3, "UniCredit", Decimal(0), Decimal(string: "5851.53")!, Decimal(string: "315.75")!, 3)
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
