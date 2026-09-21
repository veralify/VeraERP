import Foundation

/// The avalanche debt-payoff planner.
///
/// This is a deliberate port of `debtPlan()` / `simulate()` in the web app's
/// `server.js`. The ordering rules, the interest-before-payment sequence, the
/// bisection bounds and the tolerances are all load-bearing: changing any of
/// them silently changes every user's payoff schedule. `PayoffParityTests`
/// pins the behaviour against the web implementation.
public enum DebtPayoffEngine {

    /// Loop continues while any balance exceeds this. Matches the web app.
    private static let settledThreshold = Decimal(0.005)
    /// A plan "clears" when residual debt is at or under one cent.
    private static let clearedTolerance = Decimal(0.01)
    /// Bisection iteration count. Fixed rather than convergence-based so the
    /// result is deterministic, exactly as in the web app.
    private static let bisectionSteps = 50

    struct MonthSimulation {
        let paid: [Int: Decimal]
        let interest: Decimal
        let remainingDebt: Decimal
        let remainingByDebt: [Int: Decimal]
        let interestByDebt: [Int: Decimal]
    }

    struct Simulation {
        let schedule: [MonthSimulation]
        let remaining: Decimal
    }

    /// Runs `months` months of amortisation against a fixed monthly `budget`.
    ///
    /// Each month, in order: interest accrues, then every minimum payment is
    /// made in debt-id order, then any surplus goes to the highest-APR debt.
    static func simulate(debts: [Debt], budget: Decimal, months: Int) -> Simulation {
        // Debt-id order is what the web app gets from `ORDER BY id`, and it
        // decides who receives a minimum payment when the budget runs dry.
        let ordered = debts.sorted { $0.id < $1.id }
        var balances = ordered.map(\.balance)
        var schedule: [MonthSimulation] = []

        // Avalanche order: highest APR first, `priority` ascending as the
        // tie-break. Stable across months, so it is computed once.
        let avalanche = ordered.indices.sorted { lhs, rhs in
            if ordered[lhs].apr != ordered[rhs].apr {
                return ordered[lhs].apr > ordered[rhs].apr
            }
            return ordered[lhs].priority < ordered[rhs].priority
        }

        var month = 0
        while month < months, balances.contains(where: { $0 > settledThreshold }) {
            var interest: Decimal = 0
            var interestByDebt = [Int: Decimal]()
            for index in balances.indices {
                let charge = balances[index] * Money.monthlyRate(apr: ordered[index].apr)
                interest += charge
                interestByDebt[ordered[index].id] = charge
                balances[index] += charge
            }

            var remaining = budget
            var paid = [Int: Decimal]()

            // Minimums first, capped by the balance and by what is left.
            for index in ordered.indices {
                let payment = min(balances[index], ordered[index].minimumPayment, remaining)
                guard payment > 0 else { continue }
                paid[ordered[index].id, default: 0] += payment
                balances[index] -= payment
                remaining -= payment
            }

            // Then the surplus, highest APR first.
            for index in avalanche {
                guard remaining > 0 else { break }
                let payment = min(balances[index], remaining)
                guard payment > 0 else { continue }
                paid[ordered[index].id, default: 0] += payment
                balances[index] -= payment
                remaining -= payment
            }

            var remainingByDebt = [Int: Decimal]()
            for index in ordered.indices {
                remainingByDebt[ordered[index].id] = balances[index]
            }

            schedule.append(
                MonthSimulation(
                    paid: paid,
                    interest: interest,
                    remainingDebt: balances.reduce(0, +),
                    remainingByDebt: remainingByDebt,
                    interestByDebt: interestByDebt
                )
            )
            month += 1
        }

        return Simulation(schedule: schedule, remaining: balances.reduce(0, +))
    }

    /// Builds the payoff plan: finds the smallest monthly budget that clears
    /// every debt within `targetMonths`, then reports whether it is affordable.
    public static func plan(
        debts: [Debt],
        monthlyIncome: Decimal,
        monthlyExpenses: Decimal,
        targetMonths: Int,
        startDate: Date,
        calendar: Calendar = .gregorianUTC
    ) -> PayoffPlan {
        let available = max(0, monthlyIncome - monthlyExpenses)
        let totalDebt = debts.reduce(Decimal(0)) { $0 + $1.balance }

        guard !debts.isEmpty else {
            return PayoffPlan(
                monthlyIncome: monthlyIncome,
                monthlyExpenses: monthlyExpenses,
                available: available,
                totalDebt: 0,
                targetMonths: targetMonths,
                startDate: startDate,
                requiredMonthly: 0,
                isFeasible: true,
                usedMonthly: 0,
                projectedRemaining: 0,
                months: []
            )
        }

        let minimums = debts.reduce(Decimal(0)) { $0 + $1.minimumPayment }

        // Upper bound: principal plus simple interest over the whole term, which
        // is comfortably above any budget the search could need.
        let interestCeiling = debts.reduce(Decimal(0)) { total, debt in
            total + debt.balance * Money.monthlyRate(apr: debt.apr) * Decimal(targetMonths)
        }
        var low = minimums
        var high = max(minimums, available, totalDebt + interestCeiling)

        for _ in 0..<bisectionSteps {
            let mid = (low + high) / 2
            if simulate(debts: debts, budget: mid, months: targetMonths).remaining <= clearedTolerance {
                high = mid
            } else {
                low = mid
            }
        }

        let requiredMonthly = high
        let isFeasible = requiredMonthly <= available + clearedTolerance
        let usedMonthly = isFeasible ? requiredMonthly : available
        let simulation = simulate(debts: debts, budget: usedMonthly, months: targetMonths)
        let ordered = debts.sorted { $0.id < $1.id }

        let months = (0..<targetMonths).map { offset -> PayoffMonth in
            let simulated = offset < simulation.schedule.count ? simulation.schedule[offset] : nil
            var payments = [Int: Decimal]()
            var remainingByDebt = [Int: Decimal]()
            var interestByDebt = [Int: Decimal]()
            for debt in ordered {
                payments[debt.id] = Money.rounded(simulated?.paid[debt.id] ?? 0)
                remainingByDebt[debt.id] = Money.rounded(simulated?.remainingByDebt[debt.id] ?? 0)
                interestByDebt[debt.id] = Money.rounded(simulated?.interestByDebt[debt.id] ?? 0)
            }
            return PayoffMonth(
                month: Self.monthKey(startDate: startDate, offset: offset, calendar: calendar),
                payments: payments,
                totalPayment: Money.rounded(payments.values.reduce(0, +)),
                interestAccrued: Money.rounded(simulated?.interest ?? 0),
                remainingDebt: Money.rounded(simulated?.remainingDebt ?? 0),
                remainingByDebt: remainingByDebt,
                interestByDebt: interestByDebt
            )
        }

        return PayoffPlan(
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            available: available,
            totalDebt: totalDebt,
            targetMonths: targetMonths,
            startDate: startDate,
            requiredMonthly: Money.rounded(requiredMonthly),
            isFeasible: isFeasible,
            usedMonthly: Money.rounded(usedMonthly),
            projectedRemaining: Money.rounded(simulation.remaining),
            months: months
        )
    }

    /// `yyyy-MM` for the month `offset` months after `startDate`.
    static func monthKey(startDate: Date, offset: Int, calendar: Calendar) -> String {
        let shifted = calendar.date(byAdding: .month, value: offset, to: startDate) ?? startDate
        let parts = calendar.dateComponents([.year, .month], from: shifted)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}

public extension Calendar {
    /// Fixed calendar for schedule maths, so a device's timezone can never
    /// shift a month boundary.
    static let gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()
}
