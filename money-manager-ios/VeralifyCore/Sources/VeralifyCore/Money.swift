import Foundation

/// Currency is `Decimal` throughout this package, never `Double`.
///
/// The web app stores amounts as SQLite `REAL` and does its arithmetic in
/// JavaScript doubles. That is tolerable for a single pass but accumulates
/// representation error across a 16-month amortisation, so the port uses
/// decimal arithmetic instead. The two engines are expected to agree to the
/// cent, which is what `PayoffParityTests` asserts.
public enum Money {
    /// Mirrors the web app's `money(x)`: clamp negatives to zero, round to two
    /// decimal places.
    ///
    /// JavaScript's `Math.round` rounds halves toward +∞. Every value reaching
    /// this function is already clamped to be non-negative, so for halves that
    /// is the same as rounding away from zero — `.plain`.
    public static func rounded(_ value: Decimal) -> Decimal {
        var input = Swift.max(0, value)
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    /// Monthly periodic rate from an annual percentage rate.
    /// `apr` is a percentage (18.5 means 18.5%), matching the `debts.apr` column.
    public static func monthlyRate(apr: Decimal) -> Decimal {
        apr / 100 / 12
    }
}

public extension Decimal {
    /// Two-decimal string for logs and test failure messages. Not for display —
    /// user-facing formatting goes through `FormatStyle` with an explicit locale.
    var debugAmount: String {
        NSDecimalNumber(decimal: self).description
    }
}
