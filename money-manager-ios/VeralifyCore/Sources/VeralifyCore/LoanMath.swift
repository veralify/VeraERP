import Foundation

/// Annuity ("French amortisation") maths — the level-instalment model behind
/// ordinary bank loans, and the recalculation a lender performs when part of
/// one is repaid early.
///
/// This is deliberately separate from `DebtPayoffEngine`. The engine answers
/// "given a pot of money, what order do I clear these in"; this answers "the
/// lender took a lump sum off this loan, so what is the instalment now".
///
/// ## Why `Double` appears here
///
/// Every other amount in this package is `Decimal`, because rounding error
/// accumulates across an amortisation. But an annuity needs `pow` and `log`,
/// which `Decimal` does not provide. The compromise: convert at the boundary,
/// do the transcendental step in `Double`, and round the result back to cents
/// immediately. A `Double` holds ~15 significant digits, so for the magnitudes
/// involved (thousands of euros, tens of months) the error is far below a cent.
public enum LoanMath {

    /// The level monthly instalment that clears `principal` over `months`.
    ///
    /// `monthlyRate` is a fraction, not a percentage: 0.009575 for 11.49% APR.
    /// Use `Money.monthlyRate(apr:)` to get there.
    ///
    /// Returns `nil` for a non-positive term or principal.
    public static func instalment(
        principal: Decimal,
        monthlyRate: Decimal,
        months: Int
    ) -> Decimal? {
        guard months > 0, principal > 0 else { return nil }

        // An interest-free loan is just the principal split evenly.
        guard monthlyRate > 0 else {
            return Money.rounded(principal / Decimal(months))
        }

        let p = (principal as NSDecimalNumber).doubleValue
        let i = (monthlyRate as NSDecimalNumber).doubleValue
        let factor = i / (1 - pow(1 + i, -Double(months)))
        let payment = p * factor
        guard payment.isFinite, payment > 0 else { return nil }
        return Money.rounded(Decimal(payment))
    }

    /// How many monthly instalments of `instalment` the balance still holds.
    ///
    /// The inverse of `instalment(principal:monthlyRate:months:)`. A loan's
    /// remaining term does not have to be stored — balance, rate and instalment
    /// already determine it.
    ///
    /// Returns `nil` when the instalment does not cover the monthly interest,
    /// because then the balance never clears and there is no finite term.
    public static func remainingMonths(
        balance: Decimal,
        monthlyRate: Decimal,
        instalment: Decimal
    ) -> Int? {
        guard balance > 0, instalment > 0 else { return nil }

        guard monthlyRate > 0 else {
            let months = (balance / instalment as NSDecimalNumber).doubleValue
            return Int(ceil(months - roundingSlack))
        }

        let p = (balance as NSDecimalNumber).doubleValue
        let i = (monthlyRate as NSDecimalNumber).doubleValue
        let a = (instalment as NSDecimalNumber).doubleValue

        // The instalment has to out-run the interest charge or the debt grows.
        guard a > p * i else { return nil }

        let months = -log(1 - p * i / a) / log(1 + i)
        guard months.isFinite, months > 0 else { return nil }
        // A term lands just under a whole number when the final instalment is a
        // few cents light (32.997 is a 33-month loan). Anything meaningfully
        // over a whole number needs one more payment to finish.
        return Int(ceil(months - roundingSlack))
    }

    /// How far below a whole month still counts as that month.
    private static let roundingSlack = 0.02
}
