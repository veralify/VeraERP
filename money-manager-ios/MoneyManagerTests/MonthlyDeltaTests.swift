import Foundation
import Testing
@testable import MoneyManager

/// The sign of a change does not say whether it is good news: income rising and
/// debt falling are both wins. Every card on the dashboard colours its chip
/// from `isImprovement`, so the mapping has to hold in all four combinations.
struct MonthlyDeltaTests {

    @Test("Income rising is an improvement")
    func incomeUp() throws {
        let delta = try #require(MonthlyDelta.since(1600, now: 1800, risingIsGood: true))
        #expect(delta.amount == 200)
        #expect(delta.isImprovement)
    }

    @Test("Income falling is not")
    func incomeDown() throws {
        let delta = try #require(MonthlyDelta.since(1600, now: 1400, risingIsGood: true))
        #expect(delta.amount == -200)
        #expect(!delta.isImprovement)
    }

    @Test("Debt falling is an improvement")
    func debtDown() throws {
        let delta = try #require(
            MonthlyDelta.since(Decimal(string: "15343.25")!, now: Decimal(string: "14843.25")!, risingIsGood: false)
        )
        #expect(delta.amount == -500)
        #expect(delta.isImprovement)
    }

    @Test("Expenses rising is not")
    func expensesUp() throws {
        let delta = try #require(MonthlyDelta.since(1194, now: 1239, risingIsGood: false))
        #expect(delta.amount == 45)
        #expect(!delta.isImprovement)
    }

    @Test("No movement is flat, and never reads as bad news")
    func flat() throws {
        for risingIsGood in [true, false] {
            let delta = try #require(MonthlyDelta.since(1600, now: 1600, risingIsGood: risingIsGood))
            #expect(delta.isFlat)
            #expect(delta.isImprovement)
        }
    }

    @Test("No baseline yields no delta rather than a fabricated zero")
    func missingBaseline() {
        // The first month has nothing to compare against. Reporting "no change"
        // would assert something the app never measured.
        #expect(MonthlyDelta.since(nil, now: 1600, risingIsGood: true) == nil)
    }

    @Test("A month's start is the first instant of that month")
    func monthStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Rome"))

        let midMonth = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 14, minute: 37))
        )
        let expected = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )

        #expect(MonthlySnapshot.monthStart(for: midMonth, calendar: calendar) == expected)
    }

    @Test("Two dates in the same month share a start, and cross-month ones do not")
    func monthStartGroups() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Rome"))

        let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let last = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23)))
        let next = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))

        #expect(
            MonthlySnapshot.monthStart(for: first, calendar: calendar)
                == MonthlySnapshot.monthStart(for: last, calendar: calendar)
        )
        #expect(
            MonthlySnapshot.monthStart(for: next, calendar: calendar)
                != MonthlySnapshot.monthStart(for: last, calendar: calendar)
        )
    }
}
