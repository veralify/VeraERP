import Foundation

/// The stretch of time a report covers.
///
/// Every analysis in the app was locked to the current calendar month, which is
/// the right default and the wrong only option: a weekly spender wants the week,
/// and "have I always been like this" is a question about the year.
public enum Timeframe: Hashable, Sendable {
    case day
    case week
    case month
    case year
    /// Everything ever recorded.
    case all
    /// A range the user picked. Stored as two days; the interval covers both
    /// ends in full.
    case custom(start: Date, end: Date)

    /// The fixed options, in the order they are offered. `custom` is not here
    /// because it cannot exist until the user has picked its dates.
    public static let presets: [Timeframe] = [.day, .week, .month, .year, .all]

    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    /// The window this covers around `date`, or nil for everything.
    ///
    /// Ends on the first instant *after* the period rather than its last
    /// second: comparing with `<` then needs no fudging for an entry recorded
    /// at 23:59:59.7.
    public func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date)
        case .all:
            return nil
        case .custom(let start, let end):
            // Tolerates the two being handed over the wrong way round, which a
            // date picker makes easy to do.
            let low = min(start, end)
            let high = max(start, end)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: high))
            else { return nil }
            return DateInterval(start: calendar.startOfDay(for: low), end: endOfDay)
        }
    }

    /// Whether `date` falls inside. Always true for `.all`.
    public func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(containing: now, calendar: calendar) else { return true }
        // `DateInterval.contains` includes its end, which would let the first
        // instant of the next period in.
        return date >= interval.start && date < interval.end
    }
}
