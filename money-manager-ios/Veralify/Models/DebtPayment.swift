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
    /// Matches `DebtRecord.remoteID`. Synced as the debt's UUID
    /// (`money_debt_payments.debt_id`), resolved through that record.
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
    /// What applying this payment actually took off the balance. Less than
    /// `amount` when it overpaid and the balance was clamped at zero; reversing
    /// must give back only this, or undoing an overpayment inflates the debt.
    /// `nil` while unapplied, and on payments recorded before this existed.
    var appliedAmount: Decimal?
    var note: String
    var createdAt: Date

    /// Sync bookkeeping (contracts §2). Declared with defaults so a store
    /// written before sync existed opens without a mapping model — see
    /// `SyncedModel` for what each one means.
    var id: UUID = UUID()
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?
    var needsPush: Bool = true

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
        createdAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.updatedAt = createdAt
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
        let applied = min(payment.amount, max(balance, 0))
        payment.appliedAmount = applied
        balance -= applied
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
        balance += payment.appliedAmount ?? payment.amount
        payment.appliedAmount = nil
        guard let restored = payment.previousMinimum,
              let applied = payment.newMinimum,
              minimumPayment == applied
        else { return }
        minimumPayment = restored
    }
}

/// Everything keyed to a debt by its `remoteID`, removed along with it.
///
/// `DebtPayment` and the board's saved bubble positions both reference a debt
/// by a plain `Int`, not by a SwiftData relationship, so nothing cascades. That
/// would be a mere leak if ids were unique forever — but a new debt takes
/// `max(remoteID) + 1`, so deleting the highest-numbered debt hands its id, and
/// with it its entire payment history, to the next debt created. A brand-new
/// card would open already "68% paid", list payments nobody made, and fire
/// reminders under its own name.
func purgeRecords(forDebt remoteID: Int, in context: ModelContext) {
    let stale = (try? context.fetch(
        FetchDescriptor<DebtPayment>(
            predicate: #Predicate { $0.debtRemoteID == remoteID }
        )
    )) ?? []
    for payment in stale { context.deleteSynced(payment) }

    // The board remembers where the user dragged each bubble.
    let key = "boardPositions"
    if let text = UserDefaults.standard.string(forKey: key),
       let data = text.data(using: .utf8),
       var saved = try? JSONDecoder().decode([String: [Double]].self, from: data),
       saved.removeValue(forKey: "\(remoteID)") != nil,
       let encoded = try? JSONEncoder().encode(saved),
       let updated = String(data: encoded, encoding: .utf8) {
        UserDefaults.standard.set(updated, forKey: key)
    }
}
