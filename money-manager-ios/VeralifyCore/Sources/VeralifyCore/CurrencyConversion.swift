import Foundation

/// One ECB reference rate: on `day`, 1 EUR bought `rate` units of `quote`.
public struct FXRate: Sendable, Equatable, Codable {
    /// `YYYY-MM-DD`, as the server sends it. Kept as text: a calendar day, not
    /// an instant, so no time zone can move it.
    public let day: String
    public let quote: String
    public let rate: Decimal

    public init(day: String, quote: String, rate: Decimal) {
        self.day = day
        self.quote = quote
        self.rate = rate
    }
}

/// Converts between currencies with the ECB's EUR-based reference rates,
/// following exactly the server's rules (`public.money_fx_rate`):
///
/// - same currency: rate 1, no lookup;
/// - otherwise the latest publication on or before the day, because the ECB
///   does not publish on weekends and TARGET holidays;
/// - a cross rate (neither side EUR) takes both legs from the same day;
/// - nothing older than 7 days — a stale rate would be a wrong number that
///   looks right, so the answer is nil instead.
public struct CurrencyConverter: Sendable {
    public static let maxRateAgeDays = 7

    /// Rates by day (newest first), then by quote.
    private let days: [(day: String, rates: [String: Decimal])]

    public init(rates: [FXRate]) {
        var grouped: [String: [String: Decimal]] = [:]
        for rate in rates where rate.rate > 0 {
            grouped[rate.day, default: [:]][rate.quote.uppercased()] = rate.rate
        }
        days = grouped.map { (day: $0.key, rates: $0.value) }.sorted { $0.day > $1.day }
    }

    /// Units of `to` for one unit of `from` on `day`, or nil when there is no usable rate.
    public func rate(from: String, to: String, on day: String) -> Decimal? {
        let from = from.uppercased()
        let to = to.uppercased()
        if from == to { return 1 }
        guard let target = Self.dayNumber(day) else { return nil }

        for entry in days where entry.day <= day {
            guard let published = Self.dayNumber(entry.day),
                  target - published <= Self.maxRateAgeDays
            else { return nil }
            let fromRate: Decimal? = from == "EUR" ? 1 : entry.rates[from]
            let toRate: Decimal? = to == "EUR" ? 1 : entry.rates[to]
            if let fromRate, let toRate { return toRate / fromRate }
        }
        return nil
    }

    /// `amount` in `from`, expressed in `to` and rounded to cents; nil without a rate.
    public func convert(_ amount: Decimal, from: String, to: String, on day: String) -> Decimal? {
        guard let rate = rate(from: from, to: to, on: day) else { return nil }
        var value = amount * rate
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }

    /// Days since 1970-01-01 for a `YYYY-MM-DD` string, or nil if it is not a real date.
    static func dayNumber(_ day: String) -> Int? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else {
            return nil
        }
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }
}
