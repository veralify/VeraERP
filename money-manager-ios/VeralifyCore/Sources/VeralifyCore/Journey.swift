import Foundation

/// One stop on the payoff roadmap: a month, what it costs, and what it earns.
public struct JourneyStep: Hashable, Sendable, Identifiable {
    /// Zero-based position in the plan.
    public let index: Int
    /// `yyyy-MM`, matching `PayoffMonth.month`.
    public let month: String
    public let payment: Decimal
    public let interest: Decimal
    /// Total debt still owed at the end of this month.
    public let remainingDebt: Decimal
    /// Cash accumulated by the end of this month: every month's income, less
    /// expenses, less what the plan pays towards debt, added up from the start
    /// of the plan.
    ///
    /// The web app calls this `endingCash` and shows it as الرصيد التراكمي. One
    /// deliberate difference: the web wraps it in `Math.max(0, …)`, so a plan
    /// that spends more than it earns reads €0.00 every month instead of showing
    /// the hole. This keeps the real figure and lets the UI colour it — the same
    /// choice `DashboardSummary.netCashFlow` makes, for the same reason.
    ///
    /// Savings contributions are not subtracted because savings goals are not
    /// modelled on iOS yet; add them here when they land.
    public let cumulativeBalance: Decimal
    /// Names of debts that reach zero in this month, in the order they clear.
    public let clearedDebts: [String]
    /// The month the last debt disappears. Only ever one step, and only when the
    /// plan actually gets there.
    public let isFinish: Bool

    public var id: Int { index }
    public var isMilestone: Bool { !clearedDebts.isEmpty || isFinish }

    /// Fraction of the starting debt cleared by the end of this month, 0...1.
    public let progress: Double
}

/// Turns a payoff plan into the steps a roadmap draws.
///
/// Reads `PayoffMonth.remainingByDebt` rather than re-running the amortisation,
/// so the roadmap and the plan cannot disagree about when a debt clears.
public enum JourneyBuilder {
    /// Balances at or below this are settled.
    ///
    /// One cent, not the engine's half-cent. The engine compares unrounded
    /// balances; `PayoffMonth` rounds them to two places before publishing them,
    /// and the plan's bisection only converges to within a cent anyway — a
    /// sixteen-month plan ends on €0.01 outstanding. Treating that cent as a
    /// debt would mean the roadmap never reaches its own finish line.
    private static let settledThreshold = Decimal(string: "0.01")!

    public static func steps(plan: PayoffPlan, debts: [Debt]) -> [JourneyStep] {
        let names = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, $0.name) })
        // Ordered so that two debts clearing in the same month are listed the
        // way the engine pays them, not in dictionary order.
        let order = debts.sorted { $0.id < $1.id }.map(\.id)

        var outstanding = Set(debts.filter { $0.balance > settledThreshold }.map(\.id))
        let startingDebt = plan.totalDebt
        var steps: [JourneyStep] = []
        var cumulativeBalance = Decimal(0)

        for (index, month) in plan.months.enumerated() {
            cumulativeBalance += plan.monthlyIncome - plan.monthlyExpenses - month.totalPayment

            var cleared: [String] = []
            for id in order where outstanding.contains(id) {
                let remaining = month.remainingByDebt[id] ?? 0
                guard remaining <= settledThreshold else { continue }
                outstanding.remove(id)
                if let name = names[id] { cleared.append(name) }
            }

            let isFinish = outstanding.isEmpty && month.remainingDebt <= settledThreshold
            // The finish is complete by definition; leaving it at 0.99999 over a
            // cent of rounding residue would stop the bar ever filling.
            let progress: Double = isFinish ? 1 : (
                startingDebt > 0 ? 1 - (month.remainingDebt / startingDebt).doubleValue : 1
            )

            steps.append(
                JourneyStep(
                    index: index,
                    month: month.month,
                    payment: month.totalPayment,
                    interest: month.interestAccrued,
                    remainingDebt: month.remainingDebt,
                    cumulativeBalance: cumulativeBalance,
                    clearedDebts: cleared,
                    isFinish: isFinish,
                    progress: min(max(progress, 0), 1)
                )
            )

            // Nothing left to draw: the plan's remaining months are all zeros.
            if isFinish { break }
        }

        return steps
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

/// What one debt costs over the whole route.
public struct JourneyDebtTotal: Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    /// Everything paid towards it across the plan.
    public let paid: Decimal
    /// How much of that is interest rather than the balance itself.
    public let interest: Decimal
    /// `yyyy-MM` it clears, or `nil` when the plan never gets there.
    public let clearedMonth: String?

    public var principal: Decimal { paid - interest }
}

/// What the plan builds once the last debt is gone.
///
/// A plan is set for a target period, but a feasible one usually clears the debt
/// before that period is up — sixteen months asked for, thirteen months needed.
/// The route used to stop dead at the finish line, which left the most
/// encouraging part of the plan undrawn: the months where the whole payment
/// stops leaving and starts piling up instead.
public struct JourneyAfterPayoff: Hashable, Sendable {
    /// Months left in the target period once the debt is cleared.
    public let months: Int
    /// Cash free each of those months. Nothing is going to debt any more, so
    /// this is simply income less expenses.
    public let monthlySurplus: Decimal
    /// The running balance as the last debt clears.
    public let balanceAtPayoff: Decimal
    /// The running balance at the end of the target period.
    public let balanceAtEnd: Decimal
    /// `yyyy-MM` of the last month of the target period.
    public let endMonth: String

    /// What those months add, which is the figure worth showing.
    public var accumulated: Decimal { balanceAtEnd - balanceAtPayoff }
}

/// The numbers behind the route: what it costs, what the interest costs, and
/// where the money goes.
public struct JourneySummary: Hashable, Sendable {
    public let totalPaid: Decimal
    public let totalInterest: Decimal
    /// `nil` when the plan does not clear the debt in its target period.
    public let finishMonth: String?
    public let perDebt: [JourneyDebtTotal]

    public var principalPaid: Decimal { totalPaid - totalInterest }

    /// Interest as a share of everything paid, 0...1. The headline "this is what
    /// borrowing costs you" figure.
    public var interestShare: Double {
        guard totalPaid > 0 else { return 0 }
        return min(max((totalInterest / totalPaid).journeyDouble, 0), 1)
    }
}

public extension JourneyBuilder {
    /// The stretch after the finish line, or nil when there isn't one.
    ///
    /// Nil covers three cases that all mean "there is nothing to draw": a plan
    /// that never clears the debt, one that needs every month of its target
    /// period, and one with no debt to clear in the first place.
    static func afterPayoff(plan: PayoffPlan, debts: [Debt]) -> JourneyAfterPayoff? {
        let steps = steps(plan: plan, debts: debts)

        guard let finish = steps.last, finish.isFinish else { return nil }

        let remaining = plan.targetMonths - steps.count
        guard remaining > 0, let endMonth = plan.months.last?.month else { return nil }

        // No debt payment leaves any more, so the whole gap between income and
        // expenses is free.
        let surplus = plan.monthlyIncome - plan.monthlyExpenses

        return JourneyAfterPayoff(
            months: remaining,
            monthlySurplus: surplus,
            balanceAtPayoff: finish.cumulativeBalance,
            balanceAtEnd: finish.cumulativeBalance + surplus * Decimal(remaining),
            endMonth: endMonth
        )
    }

    /// Totals across the whole route, from the same plan the steps are drawn
    /// from.
    static func summary(plan: PayoffPlan, debts: [Debt]) -> JourneySummary {
        let steps = steps(plan: plan, debts: debts)
        // Only the months the roadmap actually shows: counting the plan's
        // trailing zero months would not change the totals, but reading past the
        // finish is how a figure quietly starts disagreeing with the map.
        let months = plan.months.prefix(steps.count)

        var paid = [Int: Decimal]()
        var interest = [Int: Decimal]()
        for month in months {
            for (id, value) in month.payments { paid[id, default: 0] += value }
            for (id, value) in month.interestByDebt { interest[id, default: 0] += value }
        }

        var clearedMonths = [String: String]()
        for step in steps {
            for name in step.clearedDebts { clearedMonths[name] = step.month }
        }

        let perDebt = debts.sorted { $0.id < $1.id }.map { debt in
            JourneyDebtTotal(
                id: debt.id,
                name: debt.name,
                paid: Money.rounded(paid[debt.id] ?? 0),
                interest: Money.rounded(interest[debt.id] ?? 0),
                clearedMonth: clearedMonths[debt.name]
            )
        }

        return JourneySummary(
            totalPaid: Money.rounded(months.reduce(Decimal(0)) { $0 + $1.totalPayment }),
            totalInterest: Money.rounded(months.reduce(Decimal(0)) { $0 + $1.interestAccrued }),
            finishMonth: steps.last(where: \.isFinish)?.month,
            perDebt: perDebt
        )
    }
}

private extension Decimal {
    var journeyDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}
