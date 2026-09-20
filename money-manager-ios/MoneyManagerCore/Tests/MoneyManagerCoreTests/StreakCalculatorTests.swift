import Foundation
import Testing
@testable import MoneyManagerCore

struct StreakCalculatorTests {

    private func date(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: string))
    }

    @Test("No activity is no streak")
    func empty() throws {
        #expect(StreakCalculator.current(activeDays: [], now: try date("2026-09-20")) == 0)
    }

    @Test("Consecutive days ending today count")
    func endingToday() throws {
        let days = [try date("2026-09-18"), try date("2026-09-19"), try date("2026-09-20")]
        #expect(StreakCalculator.current(activeDays: days, now: try date("2026-09-20")) == 3)
    }

    @Test("A day not yet logged does not break the streak")
    func todayStillOpen() throws {
        // Logged through yesterday, nothing today yet. The streak is alive until
        // the day actually ends — resetting it at midnight would be punitive.
        let days = [try date("2026-09-17"), try date("2026-09-18"), try date("2026-09-19")]
        #expect(StreakCalculator.current(activeDays: days, now: try date("2026-09-20")) == 3)
    }

    @Test("A missed day ends the streak")
    func gapBreaks() throws {
        let days = [try date("2026-09-15"), try date("2026-09-16"), try date("2026-09-19")]
        #expect(StreakCalculator.current(activeDays: days, now: try date("2026-09-20")) == 1)
    }

    @Test("Activity older than yesterday counts for nothing")
    func staleActivity() throws {
        let days = [try date("2026-09-01"), try date("2026-09-02")]
        #expect(StreakCalculator.current(activeDays: days, now: try date("2026-09-20")) == 0)
    }

    @Test("Several entries on one day count once")
    func duplicatesCollapse() throws {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let morning = try #require(formatter.date(from: "2026-09-20 08:00"))
        let evening = try #require(formatter.date(from: "2026-09-20 21:30"))
        #expect(StreakCalculator.current(activeDays: [morning, evening], now: try date("2026-09-20")) == 1)
    }

    @Test("The week view marks exactly the active days")
    func weekMarks() throws {
        let days = [try date("2026-09-20"), try date("2026-09-22")]
        let week = StreakCalculator.week(activeDays: days, now: try date("2026-09-22"))
        #expect(week.count == 7)
        #expect(week.filter(\.isActive).count == 2)
    }
}

struct LevelProgressTests {

    @Test("Zero XP is level 1")
    func start() {
        let progress = LevelProgress.forXP(0)
        #expect(progress.level == 1)
        #expect(progress.fraction == 0)
    }

    @Test("Levels advance at widening thresholds")
    func thresholds() {
        #expect(LevelProgress.forXP(29).level == 1)
        #expect(LevelProgress.forXP(30).level == 2)
        #expect(LevelProgress.forXP(89).level == 2)
        #expect(LevelProgress.forXP(90).level == 3)
    }

    @Test("Progress within a level is a bounded fraction")
    func fractionBounded() {
        for xp in [0, 15, 30, 75, 200, 5000] {
            let progress = LevelProgress.forXP(xp)
            #expect(progress.fraction >= 0)
            #expect(progress.fraction <= 1)
            #expect(progress.nextLevelAt > progress.levelFloor)
        }
    }

    @Test("Negative XP is clamped rather than producing a level below one")
    func negativeClamped() {
        let progress = LevelProgress.forXP(-50)
        #expect(progress.level == 1)
        #expect(progress.xp == 0)
    }
}
