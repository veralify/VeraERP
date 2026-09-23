import Foundation

/// One category's limit, against what has actually been spent on it.
public struct BudgetLine: Identifiable, Hashable, Sendable {
    public let category: String
    public let limit: Decimal
    public let spent: Decimal
    /// How many entries make up `spent`.
    public let count: Int

    public var id: String { category }

    public init(category: String, limit: Decimal, spent: Decimal, count: Int) {
        self.category = category
        self.limit = limit
        self.spent = spent
        self.count = count
    }

    /// What is left. Negative once the limit is passed — the overspend is the
    /// number worth showing, so it is not clamped away.
    public var remaining: Decimal { limit - spent }

    public var isOver: Bool { spent > limit }

    /// Share of the limit used, 0...1. Clamped because it drives a bar, and a
    /// bar that runs past its track says nothing the number does not.
    public var fraction: Double {
        guard limit > 0 else { return spent > 0 ? 1 : 0 }
        return min(max((spent / limit).budgetDouble, 0), 1)
    }

    /// True when the month is not far enough along to justify what has gone.
    ///
    /// Compares two fractions rather than two amounts: being 80% through a
    /// budget is fine on the 25th and a warning on the 5th.
    public func isAheadOfPace(monthElapsed: Double) -> Bool {
        guard limit > 0, !isOver else { return false }
        return (spent / limit).budgetDouble > monthElapsed + 0.1
    }
}

/// Every budget, with what has been spent against it.
public struct BudgetReport: Sendable {
    public let lines: [BudgetLine]
    /// How far through the month we are, 0...1.
    public let monthElapsed: Double

    public var totalLimit: Decimal { lines.reduce(Decimal(0)) { $0 + $1.limit } }
    public var totalSpent: Decimal { lines.reduce(Decimal(0)) { $0 + $1.spent } }
    public var totalRemaining: Decimal { totalLimit - totalSpent }
    public var overCount: Int { lines.filter(\.isOver).count }
    public var isEmpty: Bool { lines.isEmpty }
}

/// Measures spending against limits.
///
/// Deliberately a comparison and nothing more. A budget does not feed the payoff
/// engine, change what a month's commitments are, or move the plan — the plan is
/// what you owe and this is what you did. Wiring one into the other would mean a
/// week of takeaways quietly rewriting a debt schedule, which is not a thing a
/// budget should be able to do.
public enum BudgetTracker {

    /// Lines for every budget, biggest limit first.
    ///
    /// - Parameters:
    ///   - budgets: category and monthly limit.
    ///   - entries: category and amount, already filtered to money out this month.
    public static func report(
        budgets: [(category: String, limit: Decimal)],
        entries: [(category: String, amount: Decimal)],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BudgetReport {
        var spent: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        for entry in entries {
            spent[entry.category, default: 0] += entry.amount
            counts[entry.category, default: 0] += 1
        }

        let lines = budgets
            .map {
                BudgetLine(
                    category: $0.category,
                    limit: $0.limit,
                    spent: spent[$0.category] ?? 0,
                    count: counts[$0.category] ?? 0
                )
            }
            // Name as the tie-break so equal limits keep a stable order.
            .sorted { ($0.limit, $1.category) > ($1.limit, $0.category) }

        return BudgetReport(lines: lines, monthElapsed: elapsed(of: now, calendar: calendar))
    }

    /// How far through the current month `date` is, 0...1.
    ///
    /// Day 1 of 30 is 0, the last day is 1. Used to tell "80% spent on the 28th"
    /// from "80% spent on the 3rd", which are not the same news.
    public static func elapsed(of date: Date, calendar: Calendar = .current) -> Double {
        guard let range = calendar.range(of: .day, in: .month, for: date), range.count > 1 else {
            return 0
        }
        let day = calendar.component(.day, from: date)
        return Double(day - 1) / Double(range.count - 1)
    }

    /// Whole days left in the month, including today.
    public static func daysLeft(in date: Date, calendar: Calendar = .current) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        return range.count - calendar.component(.day, from: date) + 1
    }
}

private extension Decimal {
    var budgetDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}

// MARK: - History

/// One month of spending against the budgets.
public struct BudgetMonth: Identifiable, Hashable, Sendable {
    /// `yyyy-MM`, matching the rest of the app's month keys.
    public let month: String
    public let spentByCategory: [String: Decimal]

    public var id: String { month }

    public var total: Decimal { spentByCategory.values.reduce(Decimal(0), +) }

    public init(month: String, spentByCategory: [String: Decimal]) {
        self.month = month
        self.spentByCategory = spentByCategory
    }
}

/// How the last few months went against the current limits.
///
/// The limits are today's, applied backwards. Veralify does not keep a history
/// of limit changes, so raising a budget rewrites the past — worth knowing, and
/// the alternative is storing a limit per month that nobody would ever set.
public struct BudgetHistory: Sendable {
    public let months: [BudgetMonth]
    /// Budgeted categories, largest limit first, so a colour stays with a
    /// category across every month.
    public let categories: [String]
    public let limits: [String: Decimal]

    public var totalLimit: Decimal { limits.values.reduce(Decimal(0), +) }

    /// How much went past a limit that month, summed over every budget.
    ///
    /// Per budget, not against the total. Comparing one month's whole spend
    /// against every limit added together lets an untouched budget pay for a
    /// blown one — the screen would say "1 of 2 over the limit" at the top and
    /// "you stayed inside your budgets every month" directly underneath, which
    /// is not two views of the same fact, it is a contradiction.
    public func overspend(in month: BudgetMonth) -> Decimal {
        limits.reduce(Decimal(0)) { running, budget in
            running + max((month.spentByCategory[budget.key] ?? 0) - budget.value, 0)
        }
    }

    /// Months where any budget went past its own limit.
    public var exceededMonths: [BudgetMonth] { months.filter { overspend(in: $0) > 0 } }

    /// Average overspend across the months that went over. Nil when none did.
    public var averageOverspend: Decimal? {
        let overs = exceededMonths.map { overspend(in: $0) }
        guard !overs.isEmpty else { return nil }
        return overs.reduce(Decimal(0), +) / Decimal(overs.count)
    }

    public var isEmpty: Bool { months.isEmpty || categories.isEmpty }
}

public extension BudgetTracker {
    /// How many months of history to draw. Six fits a phone and is long enough
    /// for a pattern to show; more and the bars are too thin to compare.
    static let historyMonths = 6

    /// `yyyy-MM` for a date. The app has its own copy of this on `JourneyStep`,
    /// but that lives in the app target and core cannot reach it.
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Spending per budgeted category, month by month, oldest first.
    ///
    /// Months with nothing recorded are still included — a gap in the bars is
    /// information, and dropping them would silently compress the axis.
    static func history(
        budgets: [(category: String, limit: Decimal)],
        entries: [(category: String, amount: Decimal, date: Date)],
        months: Int = historyMonths,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BudgetHistory {
        let limits = Dictionary(budgets.map { ($0.category, $0.limit) }, uniquingKeysWith: { first, _ in first })
        let categories = budgets
            .sorted { ($0.limit, $1.category) > ($1.limit, $0.category) }
            .map(\.category)

        guard months > 0, !categories.isEmpty else {
            return BudgetHistory(months: [], categories: categories, limits: limits)
        }

        let budgeted = Set(categories)
        var buckets: [String: [String: Decimal]] = [:]
        for entry in entries where budgeted.contains(entry.category) {
            let key = monthKey(for: entry.date, calendar: calendar)
            buckets[key, default: [:]][entry.category, default: 0] += entry.amount
        }

        let keys: [String] = (0..<months).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: now)
                .map { monthKey(for: $0, calendar: calendar) }
        }

        return BudgetHistory(
            months: keys.map { BudgetMonth(month: $0, spentByCategory: buckets[$0] ?? [:]) },
            categories: categories,
            limits: limits
        )
    }
}
