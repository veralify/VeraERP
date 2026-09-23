import Foundation

/// One category's slice of a period.
public struct CategoryShare: Identifiable, Hashable, Sendable {
    public let name: String
    public let total: Decimal
    /// How many entries make it up — "1 entry" reads very differently from
    /// "31 entries" at the same total.
    public let count: Int
    /// True for the row everything past the last colour is folded into.
    public let isOther: Bool

    public var id: String { name }

    public init(name: String, total: Decimal, count: Int, isOther: Bool = false) {
        self.name = name
        self.total = total
        self.count = count
        self.isOther = isOther
    }
}

/// Ranks what was actually spent, by category.
///
/// Deliberately capped. A chart with a colour per category stops being readable
/// somewhere around six — past that the hues have to be generated, and two
/// generated hues are a pair nobody can tell apart. Everything below the cap is
/// summed into one row, which is also the honest answer: the tail is not worth
/// six colours.
public enum CategoryBreakdown {
    /// How many categories get a colour of their own.
    public static let maxSlots = 6

    /// Biggest first, with the tail folded into one row.
    ///
    /// - Parameters:
    ///   - entries: category name and amount, one per recorded entry.
    ///   - otherLabel: what to call the folded row, already localised.
    public static func ranked(
        _ entries: [(category: String, amount: Decimal)],
        otherLabel: String
    ) -> [CategoryShare] {
        guard !entries.isEmpty else { return [] }

        var totals: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        for entry in entries {
            totals[entry.category, default: 0] += entry.amount
            counts[entry.category, default: 0] += 1
        }

        let ranked = totals
            .map { CategoryShare(name: $0.key, total: $0.value, count: counts[$0.key] ?? 0) }
            // Name as the tie-break so equal totals do not reorder between
            // renders — a chart whose colours shuffle looks like the data moved.
            .sorted { ($0.total, $1.name) > ($1.total, $0.name) }

        guard ranked.count > maxSlots else { return ranked }

        let head = Array(ranked.prefix(maxSlots - 1))
        let tail = ranked.dropFirst(maxSlots - 1)

        return head + [
            CategoryShare(
                name: otherLabel,
                total: tail.reduce(Decimal(0)) { $0 + $1.total },
                count: tail.reduce(0) { $0 + $1.count },
                isOther: true
            )
        ]
    }

    /// What the ranked rows add up to.
    public static func total(_ shares: [CategoryShare]) -> Decimal {
        shares.reduce(Decimal(0)) { $0 + $1.total }
    }
}
