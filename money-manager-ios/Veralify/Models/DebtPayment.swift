import Foundation
import SwiftData

/// A payment made, or planned, against one debt.
///
/// Kept as its own record rather than just decrementing the balance: without a
/// ledger a mistyped payment is unrecoverable, and there is no way to see what
/// was actually paid versus what the plan assumed.
///
/// The balance on `DebtRecord` stays the source of truth for what is owed —
/// applying a payment reduces it, deleting one gives it back.
@Model
final class DebtPayment {
    /// Matches `DebtRecord.remoteID`.
    var debtRemoteID: Int
    /// The part that comes off the balance. On an early repayment this is the
    /// capital only — the lender's "capitale residuo rimborsato".
    var amount: Decimal
    /// Accrued interest and fees charged on top, which leave the bank account
    /// but do not reduce the debt. Zero for an ordinary instalment.
    var interestPortion: Decimal = 0
    /// When it is due to be paid, or was paid.
    var date: Date
    /// False while it is still only planned.
    var isPaid: Bool
    /// A lump sum repaid ahead of schedule, rather than a scheduled instalment.
    var isEarlyPayoff: Bool = false
    /// The instalment before this payment reduced it, so deleting can restore
    /// it. `nil` when the payment left the instalment alone.
    var previousMinimum: Decimal?
    /// The instalment this payment set. Compared against the debt's current
    /// instalment before restoring, so an older payment cannot clobber a newer
    /// one's recalculation.
    var newMinimum: Decimal?
    var note: String
    var createdAt: Date

    /// What actually left the bank account.
    var totalCharged: Decimal { amount + interestPortion }

    init(
        debtRemoteID: Int,
        amount: Decimal,
        interestPortion: Decimal = 0,
        date: Date,
        isPaid: Bool,
        isEarlyPayoff: Bool = false,
        previousMinimum: Decimal? = nil,
        newMinimum: Decimal? = nil,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.debtRemoteID = debtRemoteID
        self.amount = amount
        self.interestPortion = interestPortion
        self.date = date
        self.isPaid = isPaid
        self.isEarlyPayoff = isEarlyPayoff
        self.previousMinimum = previousMinimum
        self.newMinimum = newMinimum
        self.note = note
        self.createdAt = createdAt
    }
}

extension DebtRecord {
    /// Applies a payment, never taking the balance below zero.
    ///
    /// Overpaying the last instalment is normal — the excess simply clears the
    /// debt rather than pushing the balance negative, which would corrupt the
    /// payoff plan.
    func applyPayment(_ payment: DebtPayment) {
        balance = max(0, balance - payment.amount)
        if let recalculated = payment.newMinimum {
            minimumPayment = recalculated
        }
    }

    /// Reverses a payment, for when one is deleted or un-marked as paid.
    ///
    /// The instalment is only restored when nothing has changed it since — a
    /// later early repayment, or the user editing the debt, both win. Otherwise
    /// only the capital goes back and the instalment is left as it stands,
    /// rather than silently resurrecting a figure that is no longer true.
    func reversePayment(_ payment: DebtPayment) {
        balance += payment.amount
        guard let restored = payment.previousMinimum,
              let applied = payment.newMinimum,
              minimumPayment == applied
        else { return }
        minimumPayment = restored
    }
}
