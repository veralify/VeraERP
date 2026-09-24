import Foundation
import Testing
@testable import Veralify

/// The payment ledger has to stay reversible: the balance on `DebtRecord` is
/// the source of truth the payoff plan reads, so every way a payment can be
/// undone has to put it back exactly.
struct DebtPaymentTests {

    private func intesa() -> DebtRecord {
        DebtRecord(
            remoteID: 2, name: "Intesa",
            balance: Decimal(string: "6491.72")!,
            apr: Decimal(string: "11.49")!,
            minimumPayment: Decimal(string: "177.98")!
        )
    }

    private func payment(
        _ amount: Decimal,
        interest: Decimal = 0,
        early: Bool = false,
        previousMinimum: Decimal? = nil,
        newMinimum: Decimal? = nil
    ) -> DebtPayment {
        DebtPayment(
            debtRemoteID: 2,
            amount: amount,
            interestPortion: interest,
            date: .now,
            isPaid: true,
            isEarlyPayoff: early,
            previousMinimum: previousMinimum,
            newMinimum: newMinimum
        )
    }

    @Test("A partial payment comes off the balance and leaves the instalment alone")
    func partialPayment() {
        let debt = intesa()
        debt.applyPayment(payment(400))

        #expect(debt.balance == Decimal(string: "6091.72")!)
        #expect(debt.minimumPayment == Decimal(string: "177.98")!)
    }

    @Test("Paying more than is owed clears the debt without going negative")
    func overpaymentClampsAtZero() {
        // Otherwise the payoff engine would see a negative balance and produce
        // nonsense for every other debt in the plan.
        let debt = intesa()
        debt.applyPayment(payment(9000))

        #expect(debt.balance == 0)
    }

    @Test("Reversing a payment restores the balance exactly")
    func reverseRestoresBalance() {
        let debt = intesa()
        let first = payment(400)
        let second = payment(Decimal(string: "177.98")!)

        debt.applyPayment(first)
        debt.applyPayment(second)
        debt.reversePayment(second)
        debt.reversePayment(first)

        #expect(debt.balance == Decimal(string: "6491.72")!)
    }

    @Test("Undoing an overpayment restores what was owed, not what was paid")
    func reverseOverpaymentRestoresOriginalBalance() {
        // Applying clamps at zero, so a €9,000 payment only takes €6,491.72 off.
        // Giving back the full €9,000 on delete used to leave the debt larger
        // than it ever was.
        let debt = intesa()
        let over = payment(9000)

        debt.applyPayment(over)
        debt.reversePayment(over)

        #expect(debt.balance == Decimal(string: "6491.72")!)
    }

    @Test("A cleared debt stops costing anything each month")
    func clearedDebtHasNoMonthlyPayment() {
        // Its instalment used to stay in the monthly outgoings, reminders and
        // due list after the balance reached zero.
        let debt = intesa()
        debt.extraPayment = 50
        debt.applyPayment(payment(9000))

        #expect(debt.isPaidOff)
        #expect(debt.monthlyPayment == 0)
        #expect(debt.asDebt.minimumPayment == 0)
    }

    @Test("A payment can be marked paid, unpaid and paid again")
    func reapplyAfterReverse() {
        let debt = intesa()
        let over = payment(9000)

        debt.applyPayment(over)
        debt.reversePayment(over)
        debt.applyPayment(over)

        #expect(debt.balance == 0)
        #expect(over.appliedAmount == Decimal(string: "6491.72")!)
    }

    @Test("Only the capital of an early repayment touches the balance")
    func interestDoesNotReduceBalance() {
        // The lender charges accrued interest on top; it leaves the account but
        // is not a repayment of what is owed.
        let debt = intesa()
        let early = payment(2070, interest: Decimal(string: "8.15")!, early: true)

        debt.applyPayment(early)

        #expect(debt.balance == Decimal(string: "4421.72")!)
        #expect(early.totalCharged == Decimal(string: "2078.15")!)
    }

    @Test("An early repayment that re-amortises writes the new instalment")
    func earlyRepaymentLowersInstalment() {
        let debt = intesa()
        let early = payment(
            2070, interest: Decimal(string: "8.15")!, early: true,
            previousMinimum: Decimal(string: "177.98")!,
            newMinimum: Decimal(string: "116.75")!
        )

        debt.applyPayment(early)

        #expect(debt.minimumPayment == Decimal(string: "116.75")!)
    }

    @Test("Reversing an early repayment restores both balance and instalment")
    func reverseRestoresInstalment() {
        let debt = intesa()
        let early = payment(
            2070, early: true,
            previousMinimum: Decimal(string: "177.98")!,
            newMinimum: Decimal(string: "116.75")!
        )

        debt.applyPayment(early)
        debt.reversePayment(early)

        #expect(debt.balance == Decimal(string: "6491.72")!)
        #expect(debt.minimumPayment == Decimal(string: "177.98")!)
    }

    @Test("A stale instalment is not resurrected over a newer one")
    func doesNotClobberANewerInstalment() {
        // Undoing the older of two re-amortisations must not push the debt back
        // to a figure that two recalculations ago replaced. The capital goes
        // back; the instalment stays as it now stands.
        let debt = intesa()
        let older = payment(
            1000, early: true,
            previousMinimum: Decimal(string: "177.98")!,
            newMinimum: Decimal(string: "150.00")!
        )
        let newer = payment(
            1000, early: true,
            previousMinimum: Decimal(string: "150.00")!,
            newMinimum: Decimal(string: "120.00")!
        )

        debt.applyPayment(older)
        debt.applyPayment(newer)
        debt.reversePayment(older)

        #expect(debt.balance == Decimal(string: "5491.72")!)
        #expect(debt.minimumPayment == Decimal(string: "120.00")!)
    }

    @Test("A payment that changed nothing about the instalment leaves it untouched")
    func plainReversalIgnoresInstalment() {
        let debt = intesa()
        let plain = payment(400)

        debt.applyPayment(plain)
        debt.minimumPayment = 200  // the user edited the debt in between
        debt.reversePayment(plain)

        #expect(debt.minimumPayment == 200)
    }
}
