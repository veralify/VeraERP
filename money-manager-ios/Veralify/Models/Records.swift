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
    var minimumPayment: Decimal
    var dueDay: Int?
    var priority: Int
    var createdAt: Date

    init(
        remoteID: Int,
        name: String,
        balance: Decimal,
        apr: Decimal,
        minimumPayment: Decimal,
        dueDay: Int? = nil,
        priority: Int = 1,
        createdAt: Date = .now
    ) {
        self.remoteID = remoteID
        self.name = name
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
        self.dueDay = dueDay
        self.priority = priority
        self.createdAt = createdAt
    }

    /// The value type the payoff engine consumes.
    var asDebt: Debt {
        Debt(
            id: remoteID,
            name: name,
            balance: balance,
            apr: apr,
            minimumPayment: minimumPayment,
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

    init(targetMonths: Int = 16, startDate: Date = .now) {
        self.targetMonths = targetMonths
        self.startDate = startDate
    }
}
