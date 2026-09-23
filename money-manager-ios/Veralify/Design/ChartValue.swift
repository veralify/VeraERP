import Foundation

extension Decimal {
    /// `Decimal` for money, `Double` for geometry.
    ///
    /// Charts and bar widths need a `Double`, but nothing in this app may do
    /// arithmetic on one — a balance that has been through a binary float is a
    /// balance that no longer adds up. Converting at the point of drawing keeps
    /// the lossy step where it cannot affect a figure anyone is shown.
    var chartValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
