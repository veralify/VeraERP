import Testing
import Foundation
@testable import VeralifyCore

@Suite("Budgets")
struct BudgetTrackerTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-09-15, halfway through a 30-day month.
    private var midMonth: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!
    }

    private func budgets(_ pairs: [(String, Decimal)]) -> [(category: String, limit: Decimal)] {
        pairs.map { (category: $0.0, limit: $0.1) }
    }

    private func entries(_ pairs: [(String, Decimal)]) -> [(category: String, amount: Decimal)] {
        pairs.map { (category: $0.0, amount: $0.1) }
    }

    @Test("Spending lands on the budget for its category")
    func matchesByCategory() {
        let report = BudgetTracker.report(
            budgets: budgets([("Food", 400), ("Transport", 100)]),
            entries: entries([("Food", 120), ("Food", 30), ("Transport", 15), ("Bills", 90)]),
            now: midMonth, calendar: calendar
        )

        #expect(report.lines.first { $0.category == "Food" }?.spent == 150)
        #expect(report.lines.first { $0.category == "Transport" }?.spent == 15)
        // Spending in a category with no budget is simply not measured here.
        #expect(report.lines.count == 2)
    }

    @Test("A budget with nothing spent against it still appears, at zero")
    func untouchedBudgetsAppear() throws {
        let report = BudgetTracker.report(
            budgets: budgets([("Food", 400)]), entries: [], now: midMonth, calendar: calendar
        )
        let line = try #require(report.lines.first)

        #expect(line.spent == 0)
        #expect(line.remaining == 400)
        #expect(line.fraction == 0)
        #expect(!line.isOver)
    }

    @Test("Overspending shows the size of the overspend, not a clamped zero")
    func overspendIsVisible() throws {
        let report = BudgetTracker.report(
            budgets: budgets([("Food", 400)]),
            entries: entries([("Food", 550)]),
            now: midMonth, calendar: calendar
        )
        let line = try #require(report.lines.first)

        #expect(line.isOver)
        #expect(line.remaining == -150)
        // The bar stops at the end of its track; the number carries the rest.
        #expect(line.fraction == 1)
        #expect(report.overCount == 1)
    }

    /// The same 80% is fine late in the month and a warning early in it.
    @Test("Pace depends on the day, not only the amount")
    func paceIsRelativeToTheMonth() {
        let line = BudgetLine(category: "Food", limit: 100, spent: 80, count: 4)

        #expect(line.isAheadOfPace(monthElapsed: 0.1))
        #expect(!line.isAheadOfPace(monthElapsed: 0.9))
    }

    @Test("A budget already over is reported as over, not as ahead of pace")
    func overBeatsPace() {
        let line = BudgetLine(category: "Food", limit: 100, spent: 140, count: 4)

        #expect(line.isOver)
        #expect(!line.isAheadOfPace(monthElapsed: 0.1))
    }

    @Test("The month's elapsed share runs from nothing to everything")
    func elapsedSpansTheMonth() {
        let first = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let last = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!

        #expect(BudgetTracker.elapsed(of: first, calendar: calendar) == 0)
        #expect(BudgetTracker.elapsed(of: last, calendar: calendar) == 1)
        #expect(abs(BudgetTracker.elapsed(of: midMonth, calendar: calendar) - 0.4828) < 0.001)
    }

    @Test("Days left counts today as one of them")
    func daysLeftIncludesToday() {
        let last = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!

        #expect(BudgetTracker.daysLeft(in: midMonth, calendar: calendar) == 16)
        #expect(BudgetTracker.daysLeft(in: last, calendar: calendar) == 1)
    }

    @Test("Totals add up across every budget")
    func totalsAddUp() {
        let report = BudgetTracker.report(
            budgets: budgets([("Food", 400), ("Transport", 100), ("Fun", 50)]),
            entries: entries([("Food", 150), ("Fun", 80)]),
            now: midMonth, calendar: calendar
        )

        #expect(report.totalLimit == 550)
        #expect(report.totalSpent == 230)
        #expect(report.totalRemaining == 320)
        #expect(report.overCount == 1)
    }

    @Test("A limit of nothing is spent the moment anything is")
    func zeroLimitIsImmediatelyFull() {
        let untouched = BudgetLine(category: "Food", limit: 0, spent: 0, count: 0)
        let touched = BudgetLine(category: "Food", limit: 0, spent: 5, count: 1)

        #expect(untouched.fraction == 0)
        #expect(touched.fraction == 1)
        #expect(touched.isOver)
    }

    @Test("No budgets means nothing to report")
    func emptyIsEmpty() {
        let report = BudgetTracker.report(budgets: [], entries: entries([("Food", 10)]))
        #expect(report.isEmpty)
        #expect(report.totalLimit == 0)
    }
}

@Suite("Budget history")
struct BudgetHistoryTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var now: Date { date(2026, 9) }

    private func budgets(_ pairs: [(String, Decimal)]) -> [(category: String, limit: Decimal)] {
        pairs.map { (category: $0.0, limit: $0.1) }
    }

    private func entries(
        _ triples: [(String, Decimal, Date)]
    ) -> [(category: String, amount: Decimal, date: Date)] {
        triples.map { (category: $0.0, amount: $0.1, date: $0.2) }
    }

    @Test("Six months come back, oldest first, ending on this one")
    func spansTheWindow() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 400)]), entries: [], now: now, calendar: calendar
        )

        #expect(history.months.count == 6)
        #expect(history.months.first?.month == "2026-04")
        #expect(history.months.last?.month == "2026-09")
    }

    /// A month with nothing in it is a fact, not a gap to close up.
    @Test("Months with no spending are kept, at zero")
    func keepsEmptyMonths() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 400)]),
            entries: entries([("Food", 100, date(2026, 9))]),
            now: now, calendar: calendar
        )

        #expect(history.months.count == 6)
        #expect(history.months.dropLast().allSatisfy { $0.total == 0 })
        #expect(history.months.last?.total == 100)
    }

    @Test("Spending lands in the month it happened")
    func bucketsByMonth() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 400)]),
            entries: entries([
                ("Food", 50, date(2026, 7)),
                ("Food", 30, date(2026, 7, 28)),
                ("Food", 90, date(2026, 8))
            ]),
            now: now, calendar: calendar
        )

        #expect(history.months.first { $0.month == "2026-07" }?.total == 80)
        #expect(history.months.first { $0.month == "2026-08" }?.total == 90)
    }

    @Test("Spending outside the window, or outside a budget, is left out")
    func ignoresWhatItShould() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 400)]),
            entries: entries([
                ("Food", 999, date(2025, 1)),      // before the window
                ("Shopping", 999, date(2026, 9))   // not budgeted
            ]),
            now: now, calendar: calendar
        )

        #expect(history.months.allSatisfy { $0.total == 0 })
    }

    @Test("A month counts as exceeded when any one budget is passed")
    func countsExceededMonths() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 100), ("Transport", 50)]),
            entries: entries([
                ("Food", 200, date(2026, 8)),
                ("Food", 100, date(2026, 9)),      // exactly at the limit, not over
                ("Transport", 20, date(2026, 9))
            ]),
            now: now, calendar: calendar
        )

        #expect(history.totalLimit == 150)
        #expect(history.exceededMonths.map(\.month) == ["2026-08"])
    }

    /// The case that decides the definition: one budget blown, the combined
    /// spend still inside the combined limit. An untouched budget must not pay
    /// for a blown one.
    @Test("A blown budget counts even when the month's total is inside")
    func oneBlownBudgetCountsAlone() throws {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 40), ("Transport", 100)]),
            entries: entries([("Food", 60, date(2026, 9))]),
            now: now, calendar: calendar
        )
        let september = try #require(history.months.last)

        // 60 spent against 140 of limits — comfortably inside, in total.
        #expect(september.total < history.totalLimit)
        #expect(history.overspend(in: september) == 20)
        #expect(history.exceededMonths.map(\.month) == ["2026-09"])
    }

    @Test("Overspend adds up across every budget that went over")
    func overspendSumsAcrossBudgets() throws {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 40), ("Transport", 20)]),
            entries: entries([
                ("Food", 60, date(2026, 9)),        // 20 over
                ("Transport", 35, date(2026, 9))    // 15 over
            ]),
            now: now, calendar: calendar
        )

        #expect(history.overspend(in: try #require(history.months.last)) == 35)
    }

    @Test("The average overspend covers only the months that went over")
    func averagesTheOverspend() throws {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 100)]),
            entries: entries([
                ("Food", 150, date(2026, 7)),   // 50 over
                ("Food", 190, date(2026, 8)),   // 90 over
                ("Food", 10, date(2026, 9))     // inside, must not drag the average down
            ]),
            now: now, calendar: calendar
        )

        #expect(try #require(history.averageOverspend) == 70)
    }

    @Test("Never going over means there is no average to report")
    func noOverspendNoAverage() {
        let history = BudgetTracker.history(
            budgets: budgets([("Food", 100)]),
            entries: entries([("Food", 10, date(2026, 9))]),
            now: now, calendar: calendar
        )

        #expect(history.averageOverspend == nil)
        #expect(history.exceededMonths.isEmpty)
    }

    /// A colour is assigned by position, so the order has to be the same every
    /// month or the categories would swap colours as the ranking moved.
    @Test("Categories keep one order, largest limit first")
    func stableCategoryOrder() {
        let history = BudgetTracker.history(
            budgets: budgets([("Transport", 50), ("Food", 400), ("Fun", 120)]),
            entries: [], now: now, calendar: calendar
        )

        #expect(history.categories == ["Food", "Fun", "Transport"])
    }

    @Test("No budgets means no history to draw")
    func emptyWithoutBudgets() {
        let history = BudgetTracker.history(budgets: [], entries: [], now: now, calendar: calendar)

        #expect(history.isEmpty)
        #expect(history.months.isEmpty)
    }
}
