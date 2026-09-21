import Foundation

/// How far through a debt you are, measured from what has been recorded.
///
/// Shared by the debts list and the detail screen. The same percentage appears
/// in both, and two separate calculations of it would eventually disagree.
///
/// Progress is measured from the payment ledger, not an original loan amount —
/// the app never knew that figure. A debt with nothing recorded reads 0%, which
/// says nothing has been tracked yet rather than claiming nothing was paid.
struct DebtProgress {
    /// Principal cleared through the app.
    let paid: Decimal
    /// What was owed when tracking began: what is left, plus what has gone.
    let starting: Decimal
    /// 0...1.
    let fraction: Double

    var percent: Int { Int((fraction * 100).rounded()) }
    var hasProgress: Bool { paid > 0 }

    init(debt: DebtRecord, payments: [DebtPayment]) {
        paid = payments
            .filter { $0.debtRemoteID == debt.remoteID && $0.isPaid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        starting = debt.balance + paid

        guard starting > 0 else {
            fraction = 0
            return
        }
        let share = NSDecimalNumber(decimal: paid / starting).doubleValue
        fraction = min(max(share, 0), 1)
    }
}
