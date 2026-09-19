import Foundation
import Testing
@testable import MoneyManagerCore

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
}
