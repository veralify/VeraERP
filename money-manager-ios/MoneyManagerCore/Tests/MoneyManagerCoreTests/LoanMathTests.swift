import Testing
import Foundation
@testable import MoneyManagerCore

/// Pinned against a real Intesa Sanpaolo partial early-repayment statement
/// ("rimborso anticipato parziale", 14/09/2026), because the point of this file
/// is to reproduce what a lender actually does, not what an annuity ought to do
/// in principle.
///
/// From the statement:
/// - Importo erogato originario   6 312,00 over 43 months
/// - Tasso applicato              0,9083333 % per month
/// - Debito residuo               5 055,05   (instalment 177,98)
/// - Capitale residuo rimborsato  2 070,00
/// - Rateo interessi              8,15       (13 days)
/// - Capitale residuo dopo        2 985,05
/// - Durata residua               33 mesi
/// - Importo nuova rata           105,09
@Suite("Loan maths")
struct LoanMathTests {

    /// The statement quotes the periodic rate directly rather than an APR.
    private let rate = Decimal(string: "0.009083333")!

    @Test("Reproduces the original instalment on the original loan")
    func originalInstalment() throws {
        let payment = try #require(
            LoanMath.instalment(principal: 6312, monthlyRate: rate, months: 43)
        )
        // The statement's 177,98 comes from the lender's own day-count; a clean
        // annuity lands three cents under it.
        #expect(abs(payment - Decimal(string: "177.98")!) <= Decimal(string: "0.05")!)
    }

    @Test("Derives the remaining term from balance, rate and instalment")
    func remainingTerm() {
        let months = LoanMath.remainingMonths(
            balance: Decimal(string: "5055.05")!,
            monthlyRate: rate,
            instalment: Decimal(string: "177.98")!
        )
        #expect(months == 33)
    }

    /// The exact annuity is 105,0966. The statement quotes a rata of 105,09 but
    /// a total at maturity of 3 468,20 — which is 33 x 105,0966, so the lender
    /// truncates the instalment it prints while amortising the unrounded value.
    /// Matching that last cent is the lender's convention, not arithmetic, so
    /// the app rounds and treats its own figure as a suggestion the user can
    /// overwrite from the letter.
    @Test("Reproduces the new instalment the bank quoted, to the cent")
    func instalmentAfterEarlyRepayment() throws {
        let remaining = Decimal(string: "5055.05")! - 2070
        #expect(remaining == Decimal(string: "2985.05")!)

        let payment = try #require(
            LoanMath.instalment(principal: remaining, monthlyRate: rate, months: 33)
        )
        #expect(abs(payment - Decimal(string: "105.09")!) <= Decimal(string: "0.01")!)
    }

    @Test("A term is a whole number of payments, rounding a near-miss down")
    func termRoundsToWholePayments() {
        // 32.997 months of instalments is a 33-month loan, not 34.
        let exact = LoanMath.remainingMonths(
            balance: Decimal(string: "2985.05")!,
            monthlyRate: rate,
            instalment: Decimal(string: "105.09")!
        )
        #expect(exact == 33)
    }

    @Test("An interest-free loan splits evenly")
    func zeroRate() throws {
        let payment = try #require(
            LoanMath.instalment(principal: 3000, monthlyRate: 0, months: 6)
        )
        #expect(payment == 500)
        #expect(LoanMath.remainingMonths(balance: 3000, monthlyRate: 0, instalment: 500) == 6)
    }

    @Test("An instalment that cannot cover the interest has no finite term")
    func instalmentBelowInterest() {
        let interestOnly = Decimal(string: "5055.05")! * rate
        #expect(
            LoanMath.remainingMonths(
                balance: Decimal(string: "5055.05")!,
                monthlyRate: rate,
                instalment: interestOnly
            ) == nil
        )
    }

    @Test("Rejects terms and principals that cannot describe a loan")
    func rejectsNonsense() {
        #expect(LoanMath.instalment(principal: 1000, monthlyRate: rate, months: 0) == nil)
        #expect(LoanMath.instalment(principal: 0, monthlyRate: rate, months: 12) == nil)
        #expect(LoanMath.remainingMonths(balance: 0, monthlyRate: rate, instalment: 100) == nil)
        #expect(LoanMath.remainingMonths(balance: 1000, monthlyRate: rate, instalment: 0) == nil)
    }

    @Test("The round trip is stable: term then instalment returns the instalment")
    func roundTrip() throws {
        let balance = Decimal(string: "2985.05")!
        let months = try #require(
            LoanMath.remainingMonths(balance: balance, monthlyRate: rate, instalment: Decimal(string: "105.09")!)
        )
        let payment = try #require(
            LoanMath.instalment(principal: balance, monthlyRate: rate, months: months)
        )
        #expect(abs(payment - Decimal(string: "105.09")!) <= Decimal(string: "0.01")!)
    }
}
