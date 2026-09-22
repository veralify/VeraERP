import Foundation
import Testing
@testable import VeralifyCore

struct BillScheduleTests {

    private func date(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: string))
    }

    @Test("A day still ahead this month is the next occurrence")
    func laterThisMonth() throws {
        let next = try #require(BillSchedule.nextOccurrence(dueDay: 20, from: date("2026-09-05")))
        #expect(next == (try date("2026-09-20")))
        #expect(BillSchedule.daysUntil(dueDay: 20, from: try date("2026-09-05")) == 15)
    }

    @Test("Today counts as due today, not next month")
    func dueToday() throws {
        #expect(BillSchedule.daysUntil(dueDay: 5, from: try date("2026-09-05")) == 0)
    }

    @Test("A day already past rolls to next month")
    func alreadyPast() throws {
        let next = try #require(BillSchedule.nextOccurrence(dueDay: 1, from: date("2026-09-15")))
        #expect(next == (try date("2026-10-01")))
    }

    @Test("The 31st is clamped to the last day of a short month, never skipped")
    func clampsToShortMonth() throws {
        // February 2027 has 28 days. Rolling instead of clamping would push the
        // payment to March and silently miss the deadline.
        let next = try #require(BillSchedule.nextOccurrence(dueDay: 31, from: date("2027-02-01")))
        #expect(next == (try date("2027-02-28")))
    }

    @Test("The 29th resolves correctly in a leap February")
    func leapFebruary() throws {
        let next = try #require(BillSchedule.nextOccurrence(dueDay: 29, from: date("2028-02-01")))
        #expect(next == (try date("2028-02-29")))
    }

    @Test("Rolling into a short month still clamps")
    func rollIntoShortMonth() throws {
        let next = try #require(BillSchedule.nextOccurrence(dueDay: 30, from: date("2027-01-31")))
        #expect(next == (try date("2027-02-28")))
    }

    @Test("Out-of-range days are rejected")
    func rejectsInvalidDays() throws {
        #expect(BillSchedule.nextOccurrence(dueDay: 0, from: try date("2026-09-05")) == nil)
        #expect(BillSchedule.nextOccurrence(dueDay: 32, from: try date("2026-09-05")) == nil)
    }

    // MARK: - Scheduling ahead

    @Test("Occurrences run forward one month at a time")
    func occurrencesAdvanceMonthly() throws {
        // 2026-09-22
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = BillSchedule.occurrences(dueDay: 27, from: now, count: 4)

        #expect(dates.count == 4)
        let months = dates.map { Calendar.gregorianUTC.component(.month, from: $0) }
        #expect(months == [9, 10, 11, 12])
        #expect(dates.allSatisfy { Calendar.gregorianUTC.component(.day, from: $0) == 27 })
    }

    @Test("A 31st clamps to the last day of a short month")
    func occurrencesClampShortMonths() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = BillSchedule.occurrences(dueDay: 31, from: now, count: 6)
        let days = dates.map { Calendar.gregorianUTC.component(.day, from: $0) }

        // Sep 30, Oct 31, Nov 30, Dec 31, Jan 31, Feb 28.
        #expect(days == [30, 31, 30, 31, 31, 28])
    }

    @Test("Occurrences never repeat and never go backwards")
    func occurrencesAreStrictlyIncreasing() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = BillSchedule.occurrences(dueDay: 1, from: now, count: 5)

        #expect(dates.count == 5)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Asking for none, or for an impossible day, gives none")
    func occurrencesRejectNonsense() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(BillSchedule.occurrences(dueDay: 15, from: now, count: 0).isEmpty)
        #expect(BillSchedule.occurrences(dueDay: 0, from: now, count: 3).isEmpty)
        #expect(BillSchedule.occurrences(dueDay: 32, from: now, count: 3).isEmpty)
    }
}
