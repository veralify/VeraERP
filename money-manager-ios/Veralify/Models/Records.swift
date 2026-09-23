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

    /// What actually leaves the account for this debt each month.
    var monthlyPayment: Decimal { minimumPayment + max(extraPayment, 0) }

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
    var amount: Decimal
    var kind: String
    var payday: Int?
    var isActive: Bool
    var createdAt: Date

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
