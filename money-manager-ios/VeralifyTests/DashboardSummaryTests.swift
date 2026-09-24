import Foundation
import SwiftData
import Testing
import VeralifyCore
@testable import Veralify

/// Main-actor because `DashboardSummary` caches its plan, and the cache is.
@MainActor
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

    // MARK: - Variable income and losses

    /// Relationships need a real (in-memory) store to link up.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: IncomeSource.self, IncomeActual.self, MoneyLoss.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Money lost this month comes off this month, and leaves the plan alone")
    func lossesReduceThisMonthOnly() {
        let income = [IncomeSource(name: "Salary", amount: 2000)]
        let expenses = [ExpenseItem(name: "Rent", amount: 800)]
        let debts = [DebtRecord(remoteID: 1, name: "Card", balance: 3000, apr: 18, minimumPayment: 100)]

        let without = DashboardSummary(income: income, expenses: expenses, debts: debts, settings: nil)
        let with = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: nil,
            losses: [
                MoneyLoss(date: .now, amount: 150, reason: .stolen),
                // Last year's loss is history, not this month's problem.
                MoneyLoss(date: .now.addingTimeInterval(-400 * 86_400), amount: 999)
            ]
        )

        #expect(with.totalLosses == 150)
        #expect(with.netCashFlow == without.netCashFlow - 150)
        #expect(with.plan.requiredMonthly == without.plan.requiredMonthly)
    }

    @Test("Variable income: this month uses what was logged, the plan the average")
    func variableIncomeSplitsThisMonthFromPlan() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let thisMonth = MonthlySnapshot.monthStart(for: .now)
        let lastMonth = try #require(calendar.date(byAdding: .month, value: -1, to: thisMonth))

        let freelance = IncomeSource(name: "Freelance", amount: 1000, kind: IncomeKind.variable.rawValue)
        context.insert(freelance)
        context.insert(IncomeActual(month: lastMonth, amount: 2000, source: freelance))
        context.insert(IncomeActual(month: thisMonth, amount: 600, source: freelance))
        try context.save()

        let summary = DashboardSummary(income: [freelance], expenses: [], debts: [], settings: nil)

        #expect(summary.totalIncome == 600)
        #expect(summary.planIncome == 1300)
        #expect(!summary.incomeIsEstimated)
    }

    @Test("Variable income not yet logged this month is flagged as an estimate")
    func unloggedVariableIncomeIsEstimated() {
        let freelance = IncomeSource(name: "Freelance", amount: 1000, kind: IncomeKind.variable.rawValue)

        let summary = DashboardSummary(income: [freelance], expenses: [], debts: [], settings: nil)

        #expect(summary.totalIncome == 1000)
        #expect(summary.incomeIsEstimated)
    }

}
