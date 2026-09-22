import Testing
import Foundation
@testable import VeralifyCore

/// Three debts chosen so the strategies genuinely disagree.
///
/// The minimums are small and the surplus is large, because that is the only
/// situation where the choice matters: when a debt's own minimum clears it
/// quickly, every strategy looks the same.
@Suite("Payoff strategies")
struct PayoffStrategyTests {

    private let debts = [
        // Dearest, and the middle balance.
        Debt(id: 1, name: "Store card", balance: 800, apr: 28, minimumPayment: 20, priority: 3),
        // Smallest balance, cheapest rate.
        Debt(id: 2, name: "Loan", balance: 300, apr: 5, minimumPayment: 20, priority: 2),
        // Largest balance, middling rate — and first in the user's own order.
        Debt(id: 3, name: "Car", balance: 2000, apr: 10, minimumPayment: 20, priority: 1)
    ]

    /// Minimums total 60; the rest is surplus, which is what the strategy steers.
    private let budget = Decimal(160)
    private let months = 24

    private func schedule(_ strategy: PayoffStrategy) -> [DebtPayoffEngine.MonthSimulation] {
        DebtPayoffEngine.simulate(
            debts: debts, budget: budget, months: months, strategy: strategy
        ).schedule
    }

    /// Who the surplus goes to in the first month — which is the one thing a
    /// strategy actually decides.
    private func surplusTarget(_ strategy: PayoffStrategy) throws -> String {
        let first = try #require(schedule(strategy).first)
        let overpaid = debts.filter { (first.paid[$0.id] ?? 0) > $0.minimumPayment }
        #expect(overpaid.count == 1, "the surplus should land on one debt")
        return try #require(overpaid.first?.name)
    }

    /// The month a debt reaches zero, or nil if it never does inside the term.
    private func monthCleared(_ name: String, _ strategy: PayoffStrategy) -> Int? {
        guard let debt = debts.first(where: { $0.name == name }) else { return nil }
        return schedule(strategy).firstIndex {
            ($0.remainingByDebt[debt.id] ?? 0) <= Decimal(string: "0.01")!
        }
    }

    @Test("Avalanche puts the surplus on the dearest debt")
    func avalancheTargetsHighestRate() throws {
        #expect(try surplusTarget(.highestInterest) == "Store card")
    }

    @Test("Snowball puts the surplus on the smallest balance")
    func snowballTargetsSmallestBalance() throws {
        #expect(try surplusTarget(.smallestBalance) == "Loan")
    }

    @Test("A custom order puts the surplus where the user ranked it")
    func customFollowsPriority() throws {
        // Car is priority 1 — the target of neither other strategy.
        #expect(try surplusTarget(.custom) == "Car")
    }

    /// Why anyone would pick the more expensive strategy: the small debt is gone
    /// in months rather than more than a year.
    @Test("Snowball clears the small debt far sooner than avalanche does")
    func snowballClearsSmallDebtsSooner() throws {
        let snowball = try #require(monthCleared("Loan", .smallestBalance))
        let avalanche = try #require(monthCleared("Loan", .highestInterest))

        #expect(snowball < avalanche)
        #expect(snowball <= 3)
    }

    /// The reason avalanche is the default, stated as a test rather than a
    /// comment: at the same budget it cannot cost more.
    @Test("Avalanche never costs more interest than snowball")
    func avalancheIsTheCheapest() {
        func totalInterest(_ strategy: PayoffStrategy) -> Decimal {
            schedule(strategy).reduce(Decimal(0)) { $0 + $1.interest }
        }

        #expect(totalInterest(.highestInterest) < totalInterest(.smallestBalance))
        #expect(totalInterest(.highestInterest) <= totalInterest(.custom))
    }

    /// Whatever the strategy, a minimum is an obligation. Steering the surplus
    /// must never turn into skipping someone's payment.
    @Test("Every debt still gets its minimum under every strategy")
    func minimumsAreAlwaysPaid() throws {
        for strategy in PayoffStrategy.allCases {
            let first = try #require(schedule(strategy).first)
            for debt in debts {
                let paid = first.paid[debt.id] ?? 0
                #expect(paid >= debt.minimumPayment, "\(strategy) underpaid \(debt.name)")
            }
        }
    }

    /// Every strategy spends the same money; they differ in where it lands, so
    /// they must not differ in how much is handed over.
    @Test("Every strategy spends the whole budget while debt remains")
    func budgetIsFullySpent() throws {
        for strategy in PayoffStrategy.allCases {
            let first = try #require(schedule(strategy).first)
            let spent = first.paid.values.reduce(Decimal(0), +)
            #expect(spent == budget, "\(strategy) spent \(spent)")
        }
    }

    @Test("Changing the strategy changes the plan, not the debt it starts from")
    func planAgreesOnTheTotal() {
        func plan(_ strategy: PayoffStrategy) -> PayoffPlan {
            DebtPayoffEngine.plan(
                debts: debts,
                monthlyIncome: 2000,
                monthlyExpenses: 1840,
                targetMonths: months,
                startDate: Date(timeIntervalSince1970: 1_790_000_000),
                strategy: strategy
            )
        }

        for strategy in PayoffStrategy.allCases {
            #expect(plan(strategy).totalDebt == 3100)
        }
    }
}
