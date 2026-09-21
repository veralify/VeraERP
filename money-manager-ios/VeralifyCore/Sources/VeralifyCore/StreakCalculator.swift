import Foundation

/// Counts consecutive days of activity.
///
/// The subtle part is today: a user who has not logged anything *yet* today has
/// not broken their streak — it is still alive until the day ends. Counting
/// strictly backwards from today would reset it every morning, which is the
/// fastest way to make a streak feel punitive rather than motivating.
public enum StreakCalculator {

    /// Consecutive active days ending today or yesterday.
    /// - Parameter activeDays: any days with activity; duplicates and times of
    ///   day are fine, they are normalised.
    public static func current(
        activeDays: [Date],
        now: Date = .now,
        calendar: Calendar = .gregorianUTC
    ) -> Int {
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Start from today when it is already active, otherwise from yesterday
        // so an unlogged-but-not-over day does not zero the count.
        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The seven days of the week containing `now`, with whether each was active.
    public static func week(
        activeDays: [Date],
        now: Date = .now,
        calendar: Calendar = .gregorianUTC
    ) -> [(day: Date, isActive: Bool)] {
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let start = calendar.startOfDay(for: day)
            return (start, days.contains(start))
        }
    }
}

/// Maps earned experience onto levels.
///
/// Thresholds grow linearly rather than exponentially: this rewards steady
/// logging instead of turning into a grind that quietly stops being reachable.
public struct LevelProgress: Sendable, Equatable {
    public let level: Int
    public let xp: Int
    /// XP at which the current level started.
    public let levelFloor: Int
    /// XP needed to reach the next level.
    public let nextLevelAt: Int

    public var intoLevel: Int { xp - levelFloor }
    public var levelSpan: Int { nextLevelAt - levelFloor }
    public var fraction: Double {
        levelSpan > 0 ? min(max(Double(intoLevel) / Double(levelSpan), 0), 1) : 0
    }

    /// Level 1 spans 0–30 XP, level 2 spans 30–90, and so on in steps of 30.
    public static func forXP(_ xp: Int) -> LevelProgress {
        let step = 30
        let safe = max(0, xp)
        var level = 1
        var floor = 0
        while safe >= floor + step * level {
            floor += step * level
            level += 1
        }
        return LevelProgress(level: level, xp: safe, levelFloor: floor, nextLevelAt: floor + step * level)
    }
}
