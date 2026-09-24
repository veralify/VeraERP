import Foundation
import SwiftData
import VeralifyCore

/// SwiftData records mirroring the web app's SQLite schema.
///
/// Persistence is deliberately separate from `VeralifyCore`: the payoff
/// engine works on plain value types so it stays testable without a store and
/// can never be coupled to SwiftData's lifecycle.

@Model
final class DebtRecord {
    /// Mirrors the web row id. Used for the engine's ordering rules, which are
    /// id-sensitive, so it is assigned explicitly rather than left to SwiftData.
    var remoteID: Int
    var name: String
    var balance: Decimal
    /// Annual percentage rate as a percentage: 18.5 means 18.5%.
    var apr: Decimal
    /// What the lender requires. A floor, not a plan — it only changes when
    /// the lender changes it, so nothing in the app writes to it except the
    /// user editing it directly.
    var minimumPayment: Decimal
    /// What the user has chosen to pay on top of the minimum, each month.
    ///
    /// Separate from the minimum because the board lets you move money onto a
    /// debt and take it back again. Folded into the minimum, a month of
    /// overpaying would raise the floor permanently and there would be no way
    /// left to tell what the lender actually asks for.
    var extraPayment: Decimal = 0
    var dueDay: Int?
    var priority: Int
    var createdAt: Date

    init(
        remoteID: Int,
        name: String,
        balance: Decimal,
        apr: Decimal,
        minimumPayment: Decimal,
        extraPayment: Decimal = 0,
        dueDay: Int? = nil,
        priority: Int = 1,
        createdAt: Date = .now
    ) {
        self.remoteID = remoteID
        self.name = name
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
        self.extraPayment = extraPayment
        self.dueDay = dueDay
        self.priority = priority
        self.createdAt = createdAt
    }

    /// Cleared debts stay in the store as a record of progress, but nothing is
    /// owed on them any more.
    var isPaidOff: Bool { balance <= 0 }

    /// What actually leaves the account for this debt each month — nothing once
    /// it is cleared. Without that, a paid-off loan kept its instalment in the
    /// monthly outgoings, so net cash flow stayed understated for good.
    var monthlyPayment: Decimal {
        isPaidOff ? 0 : minimumPayment + max(extraPayment, 0)
    }

    /// The value type the payoff engine consumes.
    ///
    /// The engine takes one figure per debt and treats it as the amount
    /// committed before any surplus is steered, which is exactly what the
    /// minimum plus the chosen extra is.
    var asDebt: Debt {
        Debt(
            id: remoteID,
            name: name,
            balance: balance,
            apr: apr,
            minimumPayment: monthlyPayment,
            dueDay: dueDay,
            priority: priority
        )
    }
}

@Model
final class IncomeSource {
    var name: String
    /// For fixed income, what arrives each month. For variable income, a
    /// typical month — the plan's fallback until real months are logged.
    var amount: Decimal
    /// `IncomeKind` raw value. Stored as text so rows written before the kind
    /// was offered (all "fixed") read back unchanged.
    var kind: String
    var payday: Int?
    var isActive: Bool
    var createdAt: Date
    /// What actually came in, month by month. Only variable income is logged.
    /// Cascades, so deleting the income takes its history with it.
    @Relationship(deleteRule: .cascade, inverse: \IncomeActual.source)
    var actuals: [IncomeActual] = []

    init(
        name: String,
        amount: Decimal,
        kind: String = "fixed",
        payday: Int? = nil,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.name = name
        self.amount = amount
        self.kind = kind
        self.payday = payday
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var incomeKind: IncomeKind {
        get { IncomeKind(rawValue: kind) ?? .fixed }
        set { kind = newValue.rawValue }
    }

    private var monthlyActuals: [MonthlyAmount] {
        actuals.map { MonthlyAmount(month: $0.month, amount: $0.amount) }
    }

    /// The figure the payoff plan budgets with: the typed amount for fixed
    /// income, the recent average for variable income once months are logged.
    func planAmount(asOf date: Date = .now, calendar: Calendar = .current) -> Decimal {
        IncomeForecast.planAmount(
            kind: incomeKind, typical: amount, actuals: monthlyActuals, asOf: date, calendar: calendar
        )
    }

    /// This month's figure, and whether it is still an estimate.
    func thisMonth(asOf date: Date = .now, calendar: Calendar = .current) -> (amount: Decimal, isEstimate: Bool) {
        IncomeForecast.thisMonth(
            kind: incomeKind, typical: amount, actuals: monthlyActuals, asOf: date, calendar: calendar
        )
    }

    /// What was logged for the month containing `date`, if anything.
    func logged(inMonthOf date: Date, calendar: Calendar = .current) -> Decimal? {
        let month = MonthlySnapshot.monthStart(for: date, calendar: calendar)
        let entries = actuals.filter { MonthlySnapshot.monthStart(for: $0.month, calendar: calendar) == month }
        return entries.isEmpty ? nil : entries.reduce(Decimal(0)) { $0 + $1.amount }
    }
}

/// What one variable income actually paid in one month.
@Model
final class IncomeActual {
    /// First instant of the month, in the user's calendar.
    var month: Date
    var amount: Decimal
    var source: IncomeSource?
    var createdAt: Date

    init(month: Date, amount: Decimal, source: IncomeSource? = nil, createdAt: Date = .now) {
        self.month = month
        self.amount = amount
        self.source = source
        self.createdAt = createdAt
    }
}

/// Why money was lost. Only shapes the label and icon; every reason comes off
/// the month the same way.
enum LossReason: String, CaseIterable, Identifiable, Sendable {
    case lost, stolen, fine, unexpected, other
    var id: String { rawValue }
}

/// Money that left without being planned. It lowers what is left this month
/// and nothing else — the payoff plan is built on months that recur, and a
/// one-off does not.
@Model
final class MoneyLoss {
    var date: Date
    var amount: Decimal
    /// `LossReason` raw value.
    var reasonRaw: String
    var note: String
    var createdAt: Date

    init(date: Date = .now, amount: Decimal, reason: LossReason = .other, note: String = "", createdAt: Date = .now) {
        self.date = date
        self.amount = amount
        self.reasonRaw = reason.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    var reason: LossReason {
        get { LossReason(rawValue: reasonRaw) ?? .other }
        set { reasonRaw = newValue.rawValue }
    }
}

@Model
final class ExpenseItem {
    var name: String
    var amount: Decimal
    var category: String
    var dueDay: Int?
    var isActive: Bool
    var createdAt: Date

    init(
        name: String,
        amount: Decimal,
        category: String = "Fixed",
        dueDay: Int? = nil,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.name = name
        self.amount = amount
        self.category = category
        self.dueDay = dueDay
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// Single-row settings, mirroring the web `settings` table's two keys.
@Model
final class PlanSettings {
    var targetMonths: Int
    var startDate: Date
    /// Which debt spare money goes to. Defaulted in the declaration as well as
    /// the initialiser so an existing store migrates without a mapping: every
    /// plan made before this existed was an avalanche.
    var payoffStrategyRaw: String = PayoffStrategy.highestInterest.rawValue

    init(
        targetMonths: Int = 16,
        startDate: Date = .now,
        payoffStrategy: PayoffStrategy = .highestInterest
    ) {
        self.targetMonths = targetMonths
        self.startDate = startDate
        self.payoffStrategyRaw = payoffStrategy.rawValue
    }

    var payoffStrategy: PayoffStrategy {
        get { PayoffStrategy(rawValue: payoffStrategyRaw) ?? .highestInterest }
        set { payoffStrategyRaw = newValue.rawValue }
    }
}
