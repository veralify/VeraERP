import Foundation
import Testing
@testable import VeralifyCore

/// Variable income feeds two different calculations — the long-term plan and
/// this month's leftover — and each must use the right figure.
struct IncomeForecastTests {

    private func date(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: string))
    }

    private func logged(_ month: String, _ amount: Decimal) throws -> MonthlyAmount {
        MonthlyAmount(month: try date(month), amount: amount)
    }

    @Test("Fixed income is taken as typed, whatever was logged")
    func fixedIgnoresActuals() throws {
        let actuals = [try logged("2026-09-01", 100)]
        let now = try date("2026-09-15")

        #expect(IncomeForecast.planAmount(kind: .fixed, typical: 2000, actuals: actuals, asOf: now) == 2000)
        let month = IncomeForecast.thisMonth(kind: .fixed, typical: 2000, actuals: actuals, asOf: now)
        #expect(month.amount == 2000)
        #expect(!month.isEstimate)
    }

    @Test("Variable income with nothing logged falls back to the typical month")
    func variableWithoutHistory() throws {
        let now = try date("2026-09-15")

        #expect(IncomeForecast.planAmount(kind: .variable, typical: 1500, actuals: [], asOf: now) == 1500)
        let month = IncomeForecast.thisMonth(kind: .variable, typical: 1500, actuals: [], asOf: now)
        #expect(month.amount == 1500)
        #expect(month.isEstimate)
    }

    @Test("The plan averages the three most recent logged months")
    func planAveragesRecentMonths() throws {
        let actuals = [
            try logged("2026-05-01", 9999),  // older than the window
            try logged("2026-07-01", 1200),
            try logged("2026-08-01", 1800),
            try logged("2026-09-01", 1500)
        ]
        let now = try date("2026-09-20")

        #expect(IncomeForecast.planAmount(kind: .variable, typical: 0, actuals: actuals, asOf: now) == 1500)
    }

    @Test("A future month does not count towards the average")
    func futureMonthsIgnored() throws {
        let actuals = [try logged("2026-08-01", 1000), try logged("2026-12-01", 5000)]
        let now = try date("2026-09-10")

        #expect(IncomeForecast.planAmount(kind: .variable, typical: 0, actuals: actuals, asOf: now) == 1000)
    }

    @Test("Two entries in one month are that month's total, not two months")
    func sameMonthEntriesSum() throws {
        let actuals = [
            try logged("2026-08-03", 400),
            try logged("2026-08-20", 600),
            try logged("2026-09-05", 1000)
        ]
        let now = try date("2026-09-10")

        #expect(IncomeForecast.planAmount(kind: .variable, typical: 0, actuals: actuals, asOf: now) == 1000)
        let month = IncomeForecast.thisMonth(kind: .variable, typical: 0, actuals: actuals, asOf: now)
        #expect(month.amount == 1000)
        #expect(!month.isEstimate)
    }

    @Test("This month uses what was logged for it, not the average")
    func thisMonthUsesActual() throws {
        let actuals = [try logged("2026-08-01", 2000), try logged("2026-09-01", 800)]
        let now = try date("2026-09-25")

        let month = IncomeForecast.thisMonth(kind: .variable, typical: 1500, actuals: actuals, asOf: now)
        #expect(month.amount == 800)
        #expect(!month.isEstimate)
    }

    @Test("Before this month is logged, it is estimated from the plan figure")
    func thisMonthEstimatedFromHistory() throws {
        let actuals = [try logged("2026-07-01", 1000), try logged("2026-08-01", 2000)]
        let now = try date("2026-09-02")

        let month = IncomeForecast.thisMonth(kind: .variable, typical: 500, actuals: actuals, asOf: now)
        #expect(month.amount == 1500)
        #expect(month.isEstimate)
    }

    @Test("The average is rounded to the cent")
    func averageRounded() throws {
        let actuals = [
            try logged("2026-07-01", 100),
            try logged("2026-08-01", 100),
            try logged("2026-09-01", 101)
        ]
        let now = try date("2026-09-10")

        #expect(
            IncomeForecast.planAmount(kind: .variable, typical: 0, actuals: actuals, asOf: now)
                == Decimal(string: "100.33")
        )
    }
}

struct LossLedgerTests {

    private func date(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: string))
    }

    @Test("Only losses in the same month count")
    func onlyThisMonth() throws {
        let losses = [
            (date: try date("2026-08-31"), amount: Decimal(50)),
            (date: try date("2026-09-01"), amount: Decimal(20)),
            (date: try date("2026-09-30"), amount: Decimal(35)),
            (date: try date("2026-10-01"), amount: Decimal(90))
        ]

        #expect(LossLedger.total(losses, inMonthOf: try date("2026-09-14")) == 55)
    }

    @Test("A negative entry cannot turn a loss into a gain")
    func negativeIgnored() throws {
        let losses = [(date: try date("2026-09-03"), amount: Decimal(-40))]

        #expect(LossLedger.total(losses, inMonthOf: try date("2026-09-14")) == 0)
    }
}
