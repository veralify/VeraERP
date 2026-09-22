import Testing
import Foundation
@testable import VeralifyCore

@Suite("Payoff roadmap")
struct JourneyTests {

    /// The user's own debts, as the app seeds them.
    private let debts = [
        Debt(id: 1, name: "Court", balance: 3000, apr: 0, minimumPayment: 500),
        Debt(id: 2, name: "Intesa", balance: Decimal(string: "6491.72")!, apr: Decimal(string: "11.49")!, minimumPayment: Decimal(string: "177.98")!),
        Debt(id: 3, name: "UniCredit", balance: Decimal(string: "5851.53")!, apr: 0, minimumPayment: Decimal(string: "315.75")!)
    ]

    private func plan(income: Decimal, expenses: Decimal, months: Int = 16) -> PayoffPlan {
        DebtPayoffEngine.plan(
            debts: debts,
            monthlyIncome: income,
            monthlyExpenses: expenses,
            targetMonths: months,
            startDate: Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09
        )
    }

    @Test("Every debt clears exactly once, and the last step is the finish")
    func clearsEachDebtOnce() throws {
        let steps = JourneyBuilder.steps(plan: plan(income: 4000, expenses: 1200), debts: debts)

        let cleared = steps.flatMap(\.clearedDebts)
        #expect(Set(cleared) == Set(debts.map(\.name)))
        #expect(cleared.count == debts.count)

        let finishes = steps.filter(\.isFinish)
        #expect(finishes.count == 1)
        #expect(finishes.first?.index == steps.count - 1)
    }

    @Test("A debt clears in the month its balance reaches zero, not before")
    func clearsWhenBalanceHitsZero() throws {
        let payoffPlan = plan(income: 4000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: payoffPlan, debts: debts)

        for step in steps {
            let month = payoffPlan.months[step.index]
            for name in step.clearedDebts {
                let id = try #require(debts.first { $0.name == name }?.id)
                #expect(month.remainingByDebt[id] ?? 1 <= Decimal(string: "0.01")!)
                // And it still owed something the month before.
                if step.index > 0 {
                    let previous = payoffPlan.months[step.index - 1].remainingByDebt[id] ?? 0
                    #expect(previous > 0)
                }
            }
        }
    }

    @Test("The roadmap stops at the finish rather than trailing empty months")
    func stopsAtFinish() {
        // The plan solves for the budget that clears the debt in exactly the
        // target period, so it does not normally overshoot. It does when the
        // minimum payments alone are faster than the target asks for: 36 months
        // requested, but ~€994 of minimums clears everything in about 16.
        let payoffPlan = plan(income: 4000, expenses: 1200, months: 36)
        let steps = JourneyBuilder.steps(plan: payoffPlan, debts: debts)

        #expect(steps.count < payoffPlan.months.count)
        #expect(steps.last?.isFinish == true)
        #expect(steps.last?.remainingDebt ?? 1 <= Decimal(string: "0.01")!)
    }

    @Test("Progress rises to 1 and never leaves 0...1")
    func progressBounds() {
        let steps = JourneyBuilder.steps(plan: plan(income: 4000, expenses: 1200), debts: debts)

        #expect(steps.allSatisfy { (0...1).contains($0.progress) })
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0.progress <= $1.progress })
        #expect(steps.last?.progress == 1)
    }

    @Test("An unaffordable plan still maps out the months it can, with no finish")
    func infeasiblePlan() {
        // The user's real position: commitments exceed income.
        let payoffPlan = plan(income: 1600, expenses: 1194)
        #expect(!payoffPlan.isFeasible)

        let steps = JourneyBuilder.steps(plan: payoffPlan, debts: debts)
        #expect(steps.count == payoffPlan.months.count)
        #expect(!steps.contains { $0.isFinish })
        // It does not promise a debt-free date it cannot reach.
        #expect(steps.last?.remainingDebt ?? 0 > 0)
    }

    @Test("No debts means no roadmap rather than an empty one")
    func noDebts() {
        let empty = DebtPayoffEngine.plan(
            debts: [], monthlyIncome: 2000, monthlyExpenses: 500,
            targetMonths: 12, startDate: .now
        )
        #expect(JourneyBuilder.steps(plan: empty, debts: []).isEmpty == empty.months.isEmpty)
    }

    @Test("Step months line up with the plan's months")
    func monthsMatchPlan() {
        let payoffPlan = plan(income: 4000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: payoffPlan, debts: debts)

        for step in steps {
            #expect(step.month == payoffPlan.months[step.index].month)
            #expect(step.payment == payoffPlan.months[step.index].totalPayment)
        }
    }

    // MARK: - Summary

    @Test("Per-debt totals add up to the totals for the whole route")
    func summaryReconciles() {
        let payoffPlan = plan(income: 4000, expenses: 1200)
        let summary = JourneyBuilder.summary(plan: payoffPlan, debts: debts)

        let summedPaid = summary.perDebt.reduce(Decimal(0)) { $0 + $1.paid }
        let summedInterest = summary.perDebt.reduce(Decimal(0)) { $0 + $1.interest }

        #expect(abs(summedPaid - summary.totalPaid) <= Decimal(string: "0.05")!)
        #expect(abs(summedInterest - summary.totalInterest) <= Decimal(string: "0.05")!)
    }

    @Test("Clearing the debt costs the balance plus the interest, and no more")
    func totalPaidCoversBalanceAndInterest() {
        let payoffPlan = plan(income: 4000, expenses: 1200)
        let summary = JourneyBuilder.summary(plan: payoffPlan, debts: debts)

        let startingDebt = debts.reduce(Decimal(0)) { $0 + $1.balance }
        // Everything paid is the original debt plus what the interest added,
        // give or take the cent the bisection leaves behind.
        #expect(abs(summary.totalPaid - (startingDebt + summary.totalInterest)) <= Decimal(string: "0.05")!)
        #expect(abs(summary.principalPaid - startingDebt) <= Decimal(string: "0.05")!)
    }

    @Test("Only the debt with a rate accrues interest")
    func interestOnlyWhereThereIsARate() throws {
        let summary = JourneyBuilder.summary(plan: plan(income: 4000, expenses: 1200), debts: debts)

        let intesa = try #require(summary.perDebt.first { $0.name == "Intesa" })
        #expect(intesa.interest > 0)

        for zeroRate in summary.perDebt where zeroRate.name != "Intesa" {
            #expect(zeroRate.interest == 0)
            // A rate-free debt costs exactly what it was, bar the cent the
            // plan's bisection leaves outstanding.
            let starting = debts.first { $0.name == zeroRate.name }?.balance ?? 0
            #expect(abs(zeroRate.paid - starting) <= Decimal(string: "0.01")!)
        }
    }

    @Test("Each debt's cleared month is the step that cleared it")
    func clearedMonthsMatchSteps() {
        let payoffPlan = plan(income: 4000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: payoffPlan, debts: debts)
        let summary = JourneyBuilder.summary(plan: payoffPlan, debts: debts)

        for total in summary.perDebt {
            let step = steps.first { $0.clearedDebts.contains(total.name) }
            #expect(total.clearedMonth == step?.month)
        }
        #expect(summary.finishMonth == steps.last?.month)
    }

    @Test("An unaffordable plan reports no finish, but still credits what it clears")
    func infeasibleSummary() throws {
        let summary = JourneyBuilder.summary(plan: plan(income: 1600, expenses: 1194), debts: debts)

        #expect(summary.finishMonth == nil)
        // The route running out of road does not mean nothing gets paid off:
        // at €406 a month the whole budget goes to Court first, and it clears.
        let court = try #require(summary.perDebt.first { $0.name == "Court" })
        #expect(court.clearedMonth != nil)
        #expect(summary.perDebt.contains { $0.clearedMonth == nil })
        #expect(summary.totalPaid > 0)
    }

    @Test("The interest share stays a fraction")
    func interestShareBounds() {
        for income in [Decimal(1600), Decimal(4000), Decimal(9000)] {
            let summary = JourneyBuilder.summary(plan: plan(income: income, expenses: 1194), debts: debts)
            #expect((0...1).contains(summary.interestShare))
        }
    }

    @Test("The cumulative balance adds up each month's leftover cash")
    func cumulativeBalanceAccumulates() {
        let plan = plan(income: 4000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)

        var expected = Decimal(0)
        for (index, step) in steps.enumerated() {
            expected += 4000 - 1200 - plan.months[index].totalPayment
            #expect(step.cumulativeBalance == expected)
        }
    }

    @Test("A month's balance is the one before it plus what that month leaves over")
    func cumulativeBalanceIsMonotonicInLeftover() throws {
        let plan = plan(income: 4000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        try #require(steps.count > 1)

        for index in 1..<steps.count {
            let leftover = 4000 - 1200 - plan.months[index].totalPayment
            #expect(steps[index].cumulativeBalance - steps[index - 1].cumulativeBalance == leftover)
        }
    }

    /// The plan can never overspend: `usedMonthly` is capped at
    /// `max(0, income - expenses)`, so a household that cannot afford its debts
    /// simply pays less and ends every month on exactly zero.
    @Test("A plan that spends every spare euro on debt ends each month at zero")
    func cumulativeBalanceBottomsOutAtZero() throws {
        let plan = plan(income: 1000, expenses: 900)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)

        #expect(plan.isFeasible == false)
        #expect(steps.allSatisfy { $0.cumulativeBalance == 0 })
    }

    /// The one case that really does go below zero, and the reason this is not
    /// clamped: the web app wraps the same figure in `Math.max(0, …)`, so a
    /// household whose rent exceeds its salary reads €0.00 for sixteen months
    /// instead of −€3,200.
    @Test("Expenses above income carry the shortfall forward month after month")
    func cumulativeBalanceCarriesADeficit() throws {
        let plan = plan(income: 1000, expenses: 1200)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let last = try #require(steps.last)

        // Nothing is affordable, so nothing is paid and the gap is the whole story.
        #expect(plan.available == 0)
        #expect(steps[0].cumulativeBalance == -200)
        #expect(last.cumulativeBalance == Decimal(-200 * steps.count))
    }

    @Test("Per-debt balances sum to the plan's total each month")
    func perDebtBalancesAgreeWithTotal() {
        // The roadmap reads `remainingByDebt`; the dashboard reads
        // `remainingDebt`. If those two ever disagree the app contradicts itself.
        let payoffPlan = plan(income: 4000, expenses: 1200)

        for month in payoffPlan.months {
            let summed = month.remainingByDebt.values.reduce(Decimal(0), +)
            #expect(abs(summed - month.remainingDebt) <= Decimal(string: "0.02")!)
        }
    }

    // MARK: - After the finish line

    /// Spare months appear when the minimum payments alone clear the debt
    /// inside the target period: the plan's budget bisects down to the
    /// minimums, and the route finishes early.
    private func roomyPlan() -> PayoffPlan { plan(income: 4000, expenses: 1200, months: 24) }

    @Test("A plan that finishes early reports the months it leaves over")
    func afterPayoffCountsTheSpareMonths() throws {
        let plan = roomyPlan()
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let after = try #require(JourneyBuilder.afterPayoff(plan: plan, debts: debts))

        #expect(steps.count < 24)
        #expect(after.months == 24 - steps.count)
        #expect(after.endMonth == plan.months.last?.month)
    }

    @Test("Once the debt is gone the whole surplus accumulates")
    func afterPayoffAccumulatesTheFullSurplus() throws {
        let plan = roomyPlan()
        let after = try #require(JourneyBuilder.afterPayoff(plan: plan, debts: debts))

        // Nothing goes to debt any more, so every spare euro is free.
        #expect(after.monthlySurplus == 2800)
        #expect(after.accumulated == 2800 * Decimal(after.months))
        #expect(after.balanceAtEnd == after.balanceAtPayoff + after.accumulated)
    }

    @Test("The balance it starts from is the one the last step ended on")
    func afterPayoffContinuesFromTheFinish() throws {
        let plan = roomyPlan()
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let after = try #require(JourneyBuilder.afterPayoff(plan: plan, debts: debts))
        let finish = try #require(steps.last)

        #expect(finish.isFinish)
        #expect(after.balanceAtPayoff == finish.cumulativeBalance)
    }

    /// The usual case, and the reason this is not simply "target minus route":
    /// the budget is bisected down to the smallest that clears the debt inside
    /// the term, so a plan that needs the surplus uses every month of it.
    @Test("A plan that needs every month of its term leaves nothing after it")
    func afterPayoffIsNilWhenTheTermIsExactlyUsed() throws {
        let plan = plan(income: 4000, expenses: 1200, months: 16)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)

        #expect(steps.count == 16)
        #expect(JourneyBuilder.afterPayoff(plan: plan, debts: debts) == nil)
    }

    @Test("A plan that never clears the debt has no finish to be after")
    func afterPayoffIsNilWhenUnaffordable() {
        let plan = plan(income: 1000, expenses: 900, months: 16)

        #expect(plan.isFeasible == false)
        #expect(JourneyBuilder.afterPayoff(plan: plan, debts: debts) == nil)
    }

    @Test("No debts means no finish line and nothing after it")
    func afterPayoffIsNilWithoutDebts() {
        let empty = DebtPayoffEngine.plan(
            debts: [], monthlyIncome: 4000, monthlyExpenses: 1200,
            targetMonths: 16, startDate: Date(timeIntervalSince1970: 1_790_000_000)
        )
        #expect(JourneyBuilder.afterPayoff(plan: empty, debts: []) == nil)
    }
}
