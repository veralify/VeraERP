import Testing
import Foundation
@testable import VeralifyCore

@Suite("Timeframes")
struct TimeframeTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Fixed so the week boundaries do not depend on where the tests run.
        calendar.firstWeekday = 2  // Monday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Tuesday, 22 September 2026.
    private var now: Date { date(2026, 9, 22) }

    @Test("A day covers that day and nothing either side")
    func dayIsOneDay() {
        #expect(Timeframe.day.contains(date(2026, 9, 22, 0), now: now, calendar: calendar))
        #expect(Timeframe.day.contains(date(2026, 9, 22, 23), now: now, calendar: calendar))
        #expect(!Timeframe.day.contains(date(2026, 9, 21, 23), now: now, calendar: calendar))
        #expect(!Timeframe.day.contains(date(2026, 9, 23, 0), now: now, calendar: calendar))
    }

    @Test("A week runs from its first day to its last")
    func weekSpansSevenDays() throws {
        let interval = try #require(Timeframe.week.interval(containing: now, calendar: calendar))

        // Monday the 21st through to the start of Monday the 28th.
        #expect(interval.start == date(2026, 9, 21, 0))
        #expect(interval.end == date(2026, 9, 28, 0))
        #expect(Timeframe.week.contains(date(2026, 9, 27), now: now, calendar: calendar))
        #expect(!Timeframe.week.contains(date(2026, 9, 20), now: now, calendar: calendar))
    }

    @Test("A month stops at the month boundary")
    func monthSpansTheMonth() {
        #expect(Timeframe.month.contains(date(2026, 9, 1, 0), now: now, calendar: calendar))
        #expect(Timeframe.month.contains(date(2026, 9, 30, 23), now: now, calendar: calendar))
        #expect(!Timeframe.month.contains(date(2026, 8, 31), now: now, calendar: calendar))
        #expect(!Timeframe.month.contains(date(2026, 10, 1, 0), now: now, calendar: calendar))
    }

    @Test("A year spans January to December")
    func yearSpansTheYear() {
        #expect(Timeframe.year.contains(date(2026, 1, 1, 0), now: now, calendar: calendar))
        #expect(Timeframe.year.contains(date(2026, 12, 31, 23), now: now, calendar: calendar))
        #expect(!Timeframe.year.contains(date(2025, 12, 31), now: now, calendar: calendar))
    }

    @Test("Everything means everything")
    func allTakesEverything() {
        #expect(Timeframe.all.interval(containing: now, calendar: calendar) == nil)
        #expect(Timeframe.all.contains(date(1999, 1, 1), now: now, calendar: calendar))
        #expect(Timeframe.all.contains(date(2099, 1, 1), now: now, calendar: calendar))
    }

    /// The last day has to be included in full, or "22nd to 22nd" would cover
    /// nothing at all.
    @Test("A custom range covers both its end days completely")
    func customIncludesBothEnds() {
        let frame = Timeframe.custom(start: date(2026, 9, 10), end: date(2026, 9, 12))

        #expect(frame.contains(date(2026, 9, 10, 0), now: now, calendar: calendar))
        #expect(frame.contains(date(2026, 9, 12, 23), now: now, calendar: calendar))
        #expect(!frame.contains(date(2026, 9, 9, 23), now: now, calendar: calendar))
        #expect(!frame.contains(date(2026, 9, 13, 0), now: now, calendar: calendar))
    }

    @Test("A single day picked twice is still that whole day")
    func customSingleDay() {
        let frame = Timeframe.custom(start: date(2026, 9, 10), end: date(2026, 9, 10))

        #expect(frame.contains(date(2026, 9, 10, 0), now: now, calendar: calendar))
        #expect(frame.contains(date(2026, 9, 10, 23), now: now, calendar: calendar))
        #expect(!frame.contains(date(2026, 9, 11, 0), now: now, calendar: calendar))
    }

    /// A date picker makes it easy to set the end before the start.
    @Test("A backwards custom range is read the right way round")
    func customToleratesReversedDates() {
        let backwards = Timeframe.custom(start: date(2026, 9, 12), end: date(2026, 9, 10))

        #expect(backwards.contains(date(2026, 9, 11), now: now, calendar: calendar))
        #expect(!backwards.contains(date(2026, 9, 13), now: now, calendar: calendar))
    }

    @Test("Only custom is custom")
    func customIsRecognised() {
        #expect(Timeframe.custom(start: now, end: now).isCustom)
        #expect(Timeframe.presets.allSatisfy { !$0.isCustom })
        #expect(Timeframe.presets.count == 5)
    }
}
