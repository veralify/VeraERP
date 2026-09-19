import Foundation
import Testing
@testable import MoneyManager

struct DashboardSummaryTests {

    @Test("Net cash flow is income minus expenses, and may be negative")
    func netCashFlow() {
        let summary = DashboardSummary(
            income: [IncomeSource(name: "Salary", amount: 1600)],
            expenses: [ExpenseItem(name: "Rent", amount: 1800)],
            debts: [],
            settings: nil
        )

        #expect(summary.netCashFlow == -200)
    }

    @Test("Debt minimums come out of cash flow, and a deficit is not hidden")
    func debtMinimumsReduceCashFlow() {
        // The web app clamps this figure to zero via `money()`. Reproducing that
        // would show a household €587.73 short as "€0.00" under the positive
        // headline, so the deficit is reported honestly instead.
        let summary = DashboardSummary(
            income: [IncomeSource(name: "Salary", amount: 1600)],
            expenses: [ExpenseItem(name: "Rent", amount: 1194)],
            debts: [
                DebtRecord(remoteID: 1, name: "Court", balance: 3000, apr: 0, minimumPayment: 500),
                DebtRecord(remoteID: 2, name: "Intesa", balance: 6491.72, apr: 11.49, minimumPayment: 177.98),
                DebtRecord(remoteID: 3, name: "UniCredit", balance: 5851.53, apr: 0, minimumPayment: 315.75)
            ],
            settings: nil
        )

        #expect(summary.totalDebtMinimums == Decimal(string: "993.73"))
        #expect(summary.netCashFlow == Decimal(string: "-587.73"))
    }

    @Test("Inactive rows are excluded from the totals")
    func inactiveRowsIgnored() {
        let summary = DashboardSummary(
            income: [
                IncomeSource(name: "Salary", amount: 1000),
                IncomeSource(name: "Old job", amount: 500, isActive: false)
            ],
            expenses: [ExpenseItem(name: "Gym", amount: 50, isActive: false)],
            debts: [],
            settings: nil
        )

        #expect(summary.totalIncome == 1000)
        #expect(summary.totalExpenses == 0)
    }

    @Test("Progress is zero with no debt, and never leaves 0...1")
    func progressIsBounded() {
        let none = DashboardSummary(income: [], expenses: [], debts: [], settings: nil)
        #expect(none.progressFraction == 0)
        #expect(none.progressPercent == 0)

        // Infeasible plan: residual debt can exceed the original balance once
        // interest compounds, which must not drive progress negative.
        let stuck = DashboardSummary(
            income: [IncomeSource(name: "Salary", amount: 100)],
            expenses: [ExpenseItem(name: "Rent", amount: 90)],
            debts: [DebtRecord(remoteID: 1, name: "Card", balance: 9000, apr: 29, minimumPayment: 20)],
            settings: nil
        )
        #expect(stuck.progressFraction >= 0)
        #expect(stuck.progressFraction <= 1)
    }
}
