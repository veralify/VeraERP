import Foundation
import Testing
@testable import VeralifyCore

/// Rule-level tests for the payoff engine.
///
/// `PayoffParityTests` proves this engine agrees with the web app. These prove
/// the rules are what we think they are, so a badly regenerated fixture cannot
/// quietly redefine correct behaviour.
struct DebtPayoffEngineTests {

    private func makeDate(_ string: String) throws -> Date {
        try #require(Fixtures.date(string))
    }

    @Test("No debts is a trivially feasible, empty plan")
    func emptyDebts() throws {
        let plan = DebtPayoffEngine.plan(
            debts: [],
            monthlyIncome: 2000,
            monthlyExpenses: 500,
            targetMonths: 12,
            startDate: try makeDate("2026-01-01")
        )

        #expect(plan.isFeasible)
        #expect(plan.totalDebt == 0)
        #expect(plan.requiredMonthly == 0)
        #expect(plan.months.isEmpty)
        #expect(plan.available == 1500)
    }

    @Test("Available income never goes negative")
    func availableIsClamped() throws {
        let plan = DebtPayoffEngine.plan(
            debts: [Debt(id: 1, name: "L", balance: 100, apr: 0, minimumPayment: 10)],
            monthlyIncome: 800,
            monthlyExpenses: 1200,
            targetMonths: 6,
            startDate: try makeDate("2026-01-01")
        )

        #expect(plan.available == 0)
        #expect(!plan.isFeasible)
    }

    @Test("Surplus goes to the highest APR first, not the largest balance")
    func avalancheTargetsHighestAPR() throws {
        // The low-APR debt is far larger, so a balance-ordered (snowball-ish)
        // engine would send the surplus the other way.
        let debts = [
            Debt(id: 1, name: "BigCheap", balance: 10000, apr: 2, minimumPayment: 100, priority: 1),
            Debt(id: 2, name: "SmallExpensive", balance: 1000, apr: 25, minimumPayment: 50, priority: 2)
        ]
        let simulation = DebtPayoffEngine.simulate(debts: debts, budget: 600, months: 1)
        let month = try #require(simulation.schedule.first)

        let toExpensive = try #require(month.paid[2])
        let toCheap = try #require(month.paid[1])

        // 50 minimum + all remaining surplus (600 - 150 = 450) = 500.
        #expect(toExpensive > toCheap)
        #expect(toCheap == 100, "the cheap debt should receive only its minimum")
    }

    @Test("Equal APRs are broken by priority, lower first")
    func priorityBreaksAPRTies() throws {
        let debts = [
            Debt(id: 1, name: "Later", balance: 2000, apr: 19.9, minimumPayment: 50, priority: 9),
            Debt(id: 2, name: "Sooner", balance: 2000, apr: 19.9, minimumPayment: 50, priority: 1)
        ]
        let simulation = DebtPayoffEngine.simulate(debts: debts, budget: 500, months: 1)
        let month = try #require(simulation.schedule.first)

        #expect(try #require(month.paid[2]) > #require(month.paid[1]))
    }

    @Test("Interest accrues before payments are applied")
    func interestAccruesFirst() throws {
        // 1200 at 12% APR = 1% monthly = 12.00 of interest, charged before the
        // 100 payment lands, so the balance falls by 88, not 100.
        let debts = [Debt(id: 1, name: "L", balance: 1200, apr: 12, minimumPayment: 100)]
        let simulation = DebtPayoffEngine.simulate(debts: debts, budget: 100, months: 1)
        let month = try #require(simulation.schedule.first)

        #expect(Money.rounded(month.interest) == 12)
        #expect(Money.rounded(month.remainingDebt) == 1112)
    }

    @Test("When minimums outrun the budget, later debts get nothing")
    func minimumsAreCappedByRemainingBudget() throws {
        // Budget only covers the first minimum, and debt 1 is served first
        // because minimums are paid in id order.
        let debts = [
            Debt(id: 1, name: "First", balance: 5000, apr: 0, minimumPayment: 300, priority: 1),
            Debt(id: 2, name: "Second", balance: 5000, apr: 0, minimumPayment: 300, priority: 2)
        ]
        let simulation = DebtPayoffEngine.simulate(debts: debts, budget: 300, months: 1)
        let month = try #require(simulation.schedule.first)

        #expect(month.paid[1] == 300)
        #expect(month.paid[2] == nil || month.paid[2] == 0)
    }

    @Test("A payment never exceeds the outstanding balance")
    func paymentsNeverOverpay() throws {
        let debts = [Debt(id: 1, name: "Tiny", balance: 40, apr: 0, minimumPayment: 500)]
        let simulation = DebtPayoffEngine.simulate(debts: debts, budget: 1000, months: 3)
        let month = try #require(simulation.schedule.first)

        #expect(month.paid[1] == 40)
        #expect(simulation.remaining == 0)
        #expect(simulation.schedule.count == 1, "loop should stop once everything is settled")
    }

    @Test("Month keys run consecutively from the start date, across a year boundary")
    func monthKeysAreSequential() throws {
        let plan = DebtPayoffEngine.plan(
            debts: [Debt(id: 1, name: "L", balance: 300, apr: 0, minimumPayment: 100)],
            monthlyIncome: 1000,
            monthlyExpenses: 0,
            targetMonths: 4,
            startDate: try makeDate("2026-11-01")
        )

        #expect(plan.months.map(\.month) == ["2026-11", "2026-12", "2027-01", "2027-02"])
    }

    @Test("Rounding clamps negatives and rounds halves up")
    func moneyRounding() {
        #expect(Money.rounded(-5) == 0)
        #expect(Money.rounded(Decimal(string: "1.005")!) == Decimal(string: "1.01"))
        #expect(Money.rounded(Decimal(string: "2.344")!) == Decimal(string: "2.34"))
    }
}
