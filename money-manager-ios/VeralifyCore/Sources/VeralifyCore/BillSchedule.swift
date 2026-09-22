import Foundation

/// Works out when a monthly obligation next falls due.
///
/// Due dates are stored as a day-of-month (1...31), which does not exist in
/// every month. A debt due on the 31st must still fall due in February, so the
/// day is clamped to the last day of the target month rather than rolling into
/// the next one — rolling would silently move a payment past its deadline.
public enum BillSchedule {

    /// The next occurrence of `dueDay` at or after `date`.
    /// Returns nil when `dueDay` is outside 1...31.
    public static func nextOccurrence(
        dueDay: Int,
        from date: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Date? {
        guard (1...31).contains(dueDay) else { return nil }

        let startOfDay = calendar.startOfDay(for: date)

        // This month first; if that day has already passed, take next month.
        if let thisMonth = occurrence(dueDay: dueDay, inMonthOf: startOfDay, calendar: calendar),
           thisMonth >= startOfDay {
            return thisMonth
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfDay) else {
            return nil
        }
        return occurrence(dueDay: dueDay, inMonthOf: nextMonth, calendar: calendar)
    }

    /// The next `count` occurrences of `dueDay`, starting at or after `date`.
    ///
    /// Reminders are scheduled ahead rather than re-armed each month: a local
    /// notification only fires if it was queued before the phone was last put
    /// down, so a plan that depends on the app being opened is a plan that
    /// stops reminding the people who most need reminding.
    public static func occurrences(
        dueDay: Int,
        from date: Date,
        count: Int,
        calendar: Calendar = .gregorianUTC
    ) -> [Date] {
        guard count > 0 else { return [] }

        var dates: [Date] = []
        var cursor = date

        while dates.count < count {
            guard let next = nextOccurrence(dueDay: dueDay, from: cursor, calendar: calendar),
                  let following = calendar.date(byAdding: .day, value: 1, to: next)
            else { break }
            dates.append(next)
            cursor = following
        }

        return dates
    }

    /// Whole days from `date` until the next occurrence. Nil when undetermined.
    public static func daysUntil(
        dueDay: Int,
        from date: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Int? {
        guard let next = nextOccurrence(dueDay: dueDay, from: date, calendar: calendar) else {
            return nil
        }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: next).day
    }

    /// `dueDay` within the month containing `reference`, clamped to that
    /// month's length.
    private static func occurrence(dueDay: Int, inMonthOf reference: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: reference)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return nil }

        components.day = min(dueDay, range.count)
        return calendar.date(from: components)
    }
}
