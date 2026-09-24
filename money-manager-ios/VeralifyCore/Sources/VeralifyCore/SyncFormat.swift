import Foundation

/// Wire formats for synced values (contracts §2).
///
/// Money is a decimal string, calendar dates are `YYYY-MM-DD` in the user's
/// calendar, months are their first day, and instants are ISO 8601 in UTC.
/// Formatting and parsing are hand-rolled rather than left to a formatter:
/// `DateFormatter` follows the device locale unless every property is pinned,
/// and `ISO8601DateFormatter` disagrees between platforms about how many
/// fractional digits it accepts — Postgres sends six.
public enum SyncFormat {

    // MARK: Money

    /// Plain decimal text: no grouping, `.` as the separator, never an
    /// exponent. `Decimal.description` is locale-independent and already has
    /// that shape.
    public static func decimalString(_ value: Decimal) -> String {
        value.description
    }

    /// Parses decimal text strictly. `Decimal(string:)` alone accepts a prefix
    /// and ignores the rest ("12abc" is 12), which would quietly store a wrong
    /// figure, so the whole string has to be a number.
    public static func decimal(from text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard isDecimalLiteral(trimmed) else { return nil }
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isDecimalLiteral(_ text: String) -> Bool {
        var characters = Substring(text)
        if characters.first == "-" || characters.first == "+" { characters = characters.dropFirst() }
        let parts = characters.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty else { return false }
        if parts.count == 2, parts[1].isEmpty { return false }
        return parts.allSatisfy { $0.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    // MARK: Calendar dates

    /// `YYYY-MM-DD` for the day `date` falls on in `calendar`.
    public static func calendarDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 1, parts.day ?? 1)
    }

    /// The start of the day `text` names, in `calendar`.
    public static func date(fromCalendarDate text: String, calendar: Calendar) -> Date? {
        let pieces = text.prefix(10).split(separator: "-")
        guard text.count >= 10, pieces.count == 3,
              let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day
        else { return nil }
        return date
    }

    /// `YYYY-MM-01` for the month containing `date`.
    public static func monthDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d-01", parts.year ?? 0, parts.month ?? 1)
    }

    // MARK: Instants

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// ISO 8601 in UTC with milliseconds, e.g. `2026-09-25T10:04:05.120Z`.
    ///
    /// Milliseconds, not the full precision of `Date`: the value comes back
    /// from Postgres rounded to microseconds, and an instant that did not
    /// survive the round trip exactly would make the row look edited forever.
    public static func instant(_ date: Date) -> String {
        // Nearest, not down: a parsed ".123" is 0.12299999… as a Double, and
        // rounding down would turn it into ".122" on the way back out.
        let millis = (date.timeIntervalSince1970 * 1000).rounded()
        let whole = Date(timeIntervalSince1970: (millis / 1000).rounded(.down))
        let fraction = Int(millis - (millis / 1000).rounded(.down) * 1000)
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
            parts.year ?? 0, parts.month ?? 1, parts.day ?? 1,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0,
            fraction
        )
    }


    /// Parses what PostgREST sends for a `timestamptz` — `2026-09-25T10:04:05.123456+00:00`
    /// — and the `Z` form this app writes. Any number of fractional digits,
    /// and a `T` or a space between date and time.
    public static func date(fromInstant text: String) -> Date? {
        let scalars = Array(text.utf8)
        func number(_ start: Int, _ length: Int) -> Int? {
            guard start + length <= scalars.count else { return nil }
            var value = 0
            for index in start..<(start + length) {
                let byte = scalars[index]
                guard byte >= 48, byte <= 57 else { return nil }
                value = value * 10 + Int(byte - 48)
            }
            return value
        }
        guard scalars.count >= 19,
              let year = number(0, 4), scalars[4] == UInt8(ascii: "-"),
              let month = number(5, 2), scalars[7] == UInt8(ascii: "-"),
              let day = number(8, 2),
              scalars[10] == UInt8(ascii: "T") || scalars[10] == UInt8(ascii: " "),
              let hour = number(11, 2), scalars[13] == UInt8(ascii: ":"),
              let minute = number(14, 2), scalars[16] == UInt8(ascii: ":"),
              let second = number(17, 2)
        else { return nil }

        var index = 19
        var fraction: Double = 0
        if index < scalars.count, scalars[index] == UInt8(ascii: ".") {
            index += 1
            var scale = 0.1
            while index < scalars.count, scalars[index] >= 48, scalars[index] <= 57 {
                fraction += Double(scalars[index] - 48) * scale
                scale /= 10
                index += 1
            }
        }

        var offsetSeconds = 0
        if index < scalars.count {
            let sign = scalars[index]
            if sign == UInt8(ascii: "Z") || sign == UInt8(ascii: "z") {
                index += 1
            } else if sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") {
                guard let hours = number(index + 1, 2) else { return nil }
                var minutes = 0
                var next = index + 3
                if next < scalars.count, scalars[next] == UInt8(ascii: ":") { next += 1 }
                if let parsed = number(next, 2) {
                    minutes = parsed
                    next += 2
                }
                offsetSeconds = (hours * 3600 + minutes * 60) * (sign == UInt8(ascii: "-") ? -1 : 1)
                index = next
            } else {
                return nil
            }
        } else {
            // No zone at all is not an instant; guessing one would shift it.
            return nil
        }
        guard index == scalars.count else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let base = utc.date(from: components) else { return nil }
        return base.addingTimeInterval(fraction - Double(offsetSeconds))
    }
}
