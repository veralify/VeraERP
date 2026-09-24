import Foundation

/// Whether an income arrives as the same figure every month or moves around.
public enum IncomeKind: String, Sendable, CaseIterable {
    /// A salary or pension: the typed figure is what arrives.
    case fixed
    /// Freelance work, commission, tips: the typed figure is a typical month,
    /// and what actually came in is logged month by month.
    case variable
}

/// An amount attributed to a calendar month.
public struct MonthlyAmount: Sendable, Equatable {
    public let month: Date
    public let amount: Decimal

    public init(month: Date, amount: Decimal) {
        self.month = month
        self.amount = amount
    }
}

/// Works out which income figure each calculation should use.
///
/// Two questions get two different answers for variable pay. "What can the
/// plan count on?" is best answered by recent history, so one good month does
/// not commit the household to payments a lean month cannot meet. "What came
/// in this month?" is answered by what the user logged, once they have — an
/// estimate only stands in until then.
public enum IncomeForecast {

    /// How many logged months the plan averages over.
    public static let averagingWindow = 3

    /// The monthly figure the payoff plan budgets with.
    ///
    /// Fixed income is taken as typed. Variable income is the average of the
    /// most recent logged months (up to `averagingWindow`, this month included,
    /// future months ignored), falling back to the typical figure until
    /// anything has been logged.
    public static func planAmount(
        kind: IncomeKind,
        typical: Decimal,
        actuals: [MonthlyAmount],
        asOf date: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Decimal {
        guard kind == .variable else { return typical }

        let recent = monthlyTotals(actuals, upTo: date, calendar: calendar)
            .suffix(averagingWindow)
        guard !recent.isEmpty else { return typical }

        let total = recent.reduce(Decimal(0)) { $0 + $1.amount }
        return Money.rounded(total / Decimal(recent.count))
    }

    /// This month's income, and whether it is still an estimate.
    ///
    /// A variable income with nothing logged for the month uses the plan figure
    /// and says so, so the screen can ask for the real number rather than
    /// presenting a guess as fact.
    public static func thisMonth(
        kind: IncomeKind,
        typical: Decimal,
        actuals: [MonthlyAmount],
        asOf date: Date,
        calendar: Calendar = .gregorianUTC
    ) -> (amount: Decimal, isEstimate: Bool) {
        guard kind == .variable else { return (typical, false) }

        let current = monthStart(of: date, calendar: calendar)
        let logged = actuals.filter { monthStart(of: $0.month, calendar: calendar) == current }
        if !logged.isEmpty {
            return (logged.reduce(Decimal(0)) { $0 + $1.amount }, false)
        }
        return (
            planAmount(kind: kind, typical: typical, actuals: actuals, asOf: date, calendar: calendar),
            true
        )
    }

    /// One total per logged month up to and including the month of `date`,
    /// oldest first. Two entries in the same month are one month's pay, not two
    /// months, so they are summed before averaging.
    static func monthlyTotals(
        _ actuals: [MonthlyAmount],
        upTo date: Date,
        calendar: Calendar
    ) -> [MonthlyAmount] {
        let limit = monthStart(of: date, calendar: calendar)
        let grouped = Dictionary(grouping: actuals) { monthStart(of: $0.month, calendar: calendar) }
        return grouped
            .filter { $0.key <= limit }
            .map { MonthlyAmount(month: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }
    }

    static func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

/// Money that left without being planned: lost, stolen, a fine, a cost nobody
/// saw coming.
///
/// It comes out of the month it happened in and nothing else. A one-off does
/// not recur, so letting it reshape the long-term payoff plan would punish
/// every later month for one bad one.
public enum LossLedger {

    /// Everything lost in the month containing `date`.
    public static func total(
        _ losses: [(date: Date, amount: Decimal)],
        inMonthOf date: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Decimal {
        let month = IncomeForecast.monthStart(of: date, calendar: calendar)
        return losses
            .filter { IncomeForecast.monthStart(of: $0.date, calendar: calendar) == month }
            .reduce(Decimal(0)) { $0 + max($1.amount, 0) }
    }
}
