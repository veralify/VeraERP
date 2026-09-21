import Foundation
import VeralifyCore

/// Remembers the last payoff plan, keyed by the figures that produce it.
///
/// The engine bisects fifty times over the whole schedule — about 10ms — and
/// `DashboardSummary` is built by the dashboard, the alerts badge, the roadmap
/// and the charts, several times per render each. The roadmap was the worst:
/// deciding whether a step was done, current or upcoming read a computed
/// property that ran a whole plan, once per row. Switching its segmented
/// control could run the engine twenty times over.
///
/// The plan is a pure function of its inputs, so remembering one is safe: the
/// same figures cannot produce a different schedule.
@MainActor
enum PlanCache {
    private struct Key: Equatable {
        let debts: [Debt]
        let income: Decimal
        let expenses: Decimal
        let targetMonths: Int
        let startDate: Date
    }

    private static var key: Key?
    private static var cached: PayoffPlan?

    static func plan(
        debts: [Debt],
        monthlyIncome: Decimal,
        monthlyExpenses: Decimal,
        targetMonths: Int,
        startDate: Date
    ) -> PayoffPlan {
        let candidate = Key(
            debts: debts,
            income: monthlyIncome,
            expenses: monthlyExpenses,
            targetMonths: targetMonths,
            startDate: startDate
        )
        if candidate == key, let cached { return cached }

        let fresh = DebtPayoffEngine.plan(
            debts: debts,
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            targetMonths: targetMonths,
            startDate: startDate
        )
        key = candidate
        cached = fresh
        return fresh
    }

    /// A stable stand-in for "today" when there are no plan settings yet.
    ///
    /// `Date.now` read at each call made the month labels drift between renders,
    /// and gave the cache a different key every time so it could never hit.
    static let sessionStart = Date()
}
