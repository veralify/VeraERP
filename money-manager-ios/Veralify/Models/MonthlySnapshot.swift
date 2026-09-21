import Foundation
import SwiftData
import VeralifyCore

/// What the plan looked like when a month began.
///
/// `IncomeSource`, `ExpenseItem` and `DebtRecord` describe the plan as it
/// stands right now — editing one leaves no trace of what it used to be. So a
/// month-on-month figure cannot be derived from them; it has to be recorded.
/// One row is written the first time the app is opened in a month, and the
/// dashboard compares today's totals against it.
///
/// A month first seen halfway through is baselined from that moment, not from
/// the 1st. The alternative would be to invent a figure for days the app never
/// saw.
@Model
final class MonthlySnapshot {
    /// First instant of the month this describes, in the user's calendar.
    @Attribute(.unique) var month: Date
    var income: Decimal
    var expenses: Decimal
    var debtMinimums: Decimal
    var debtBalance: Decimal
    var recordedAt: Date

    init(
        month: Date,
        income: Decimal,
        expenses: Decimal,
        debtMinimums: Decimal,
        debtBalance: Decimal,
        recordedAt: Date = .now
    ) {
        self.month = month
        self.income = income
        self.expenses = expenses
        self.debtMinimums = debtMinimums
        self.debtBalance = debtBalance
        self.recordedAt = recordedAt
    }

    /// Start of the month containing `date`.
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

/// How one figure moved since the month began.
struct MonthlyDelta: Equatable {
    let amount: Decimal
    /// Whether the movement is the direction the user wants. Income rising and
    /// debt falling are both good; the sign alone does not say which.
    let isImprovement: Bool

    var isFlat: Bool { amount == 0 }

    /// `nil` when there is no baseline to compare against — the first month,
    /// where claiming "no change" would assert something unmeasured.
    static func since(_ baseline: Decimal?, now: Decimal, risingIsGood: Bool) -> MonthlyDelta? {
        guard let baseline else { return nil }
        let change = now - baseline
        return MonthlyDelta(
            amount: change,
            isImprovement: change == 0 || ((change > 0) == risingIsGood)
        )
    }
}
