import Foundation

/// A debt to be paid off. Mirrors the `debts` table in the web app.
public struct Debt: Identifiable, Hashable, Sendable {
    public let id: Int
    public var name: String
    public var balance: Decimal
    /// Annual percentage rate as a percentage: 18.5 means 18.5%.
    public var apr: Decimal
    public var minimumPayment: Decimal
    public var dueDay: Int?
    /// Tie-breaker when two debts share an APR. Lower wins.
    public var priority: Int

    public init(
        id: Int,
        name: String,
        balance: Decimal,
        apr: Decimal,
        minimumPayment: Decimal,
        dueDay: Int? = nil,
        priority: Int = 1
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
        self.dueDay = dueDay
        self.priority = priority
    }
}

/// One month of the payoff schedule.
public struct PayoffMonth: Hashable, Sendable {
    /// `yyyy-MM`, matching the web app's month keys.
    public let month: String
    /// Amount paid to each debt this month, keyed by `Debt.id`.
    public let payments: [Int: Decimal]
    public let totalPayment: Decimal
    public let interestAccrued: Decimal
    /// Total debt remaining across all debts at the end of the month.
    public let remainingDebt: Decimal
    /// Remaining balance per debt at the end of the month, keyed by `Debt.id`.
    ///
    /// Published by the engine rather than re-derived by callers: working out
    /// when a debt clears needs per-debt balances, and a second implementation
    /// of the amortisation would be free to disagree with this one.
    public let remainingByDebt: [Int: Decimal]
    /// Interest charged per debt this month, keyed by `Debt.id`. Same reasoning
    /// as `remainingByDebt`: the engine already has it, so nothing else has to
    /// reimplement the accrual to report it.
    public let interestByDebt: [Int: Decimal]

    public init(
        month: String,
        payments: [Int: Decimal],
        totalPayment: Decimal,
        interestAccrued: Decimal,
        remainingDebt: Decimal,
        remainingByDebt: [Int: Decimal] = [:],
        interestByDebt: [Int: Decimal] = [:]
    ) {
        self.month = month
        self.payments = payments
        self.totalPayment = totalPayment
        self.interestAccrued = interestAccrued
        self.remainingDebt = remainingDebt
        self.remainingByDebt = remainingByDebt
        self.interestByDebt = interestByDebt
    }
}

/// The result of running the payoff planner.
public struct PayoffPlan: Hashable, Sendable {
    public let monthlyIncome: Decimal
    public let monthlyExpenses: Decimal
    /// `max(0, income - expenses)` — what is actually spendable on debt.
    public let available: Decimal
    public let totalDebt: Decimal
    public let targetMonths: Int
    public let startDate: Date

    /// The smallest monthly budget that clears every debt within `targetMonths`.
    public let requiredMonthly: Decimal
    /// False when `requiredMonthly` exceeds what the user can actually afford.
    public let isFeasible: Bool
    /// What the projection actually ran with: `requiredMonthly` when feasible,
    /// otherwise `available`.
    public let usedMonthly: Decimal
    /// Debt still outstanding after `targetMonths`. Zero for a feasible plan.
    public let projectedRemaining: Decimal
    public let months: [PayoffMonth]
}
