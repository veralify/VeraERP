import Testing
import Foundation
@testable import VeralifyCore

@Suite("Category breakdown")
struct CategoryBreakdownTests {

    private func entries(_ pairs: [(String, Decimal)]) -> [(category: String, amount: Decimal)] {
        pairs.map { (category: $0.0, amount: $0.1) }
    }

    @Test("Categories rank by total, biggest first")
    func ranksByTotal() {
        let shares = CategoryBreakdown.ranked(
            entries([("Food", 20), ("Bills", 100), ("Food", 15)]),
            otherLabel: "Other"
        )

        #expect(shares.map(\.name) == ["Bills", "Food"])
        #expect(shares[0].total == 100)
        #expect(shares[1].total == 35)
    }

    @Test("Each row counts the entries behind it")
    func countsEntries() {
        let shares = CategoryBreakdown.ranked(
            entries([("Food", 20), ("Food", 15), ("Food", 5), ("Bills", 100)]),
            otherLabel: "Other"
        )

        #expect(shares.first { $0.name == "Food" }?.count == 3)
        #expect(shares.first { $0.name == "Bills" }?.count == 1)
    }

    @Test("Past the colour cap the tail folds into one row")
    func foldsTheTail() {
        let many = entries((1...9).map { ("Category \($0)", Decimal($0 * 10)) })
        let shares = CategoryBreakdown.ranked(many, otherLabel: "Other")

        #expect(shares.count == CategoryBreakdown.maxSlots)
        let other = shares.last!
        #expect(other.isOther)
        // The four smallest: 10 + 20 + 30 + 40.
        #expect(other.total == 100)
        #expect(other.count == 4)
    }

    /// Folding must not lose money — the chart and the headline come from the
    /// same rows, so a dropped euro would show up as a slice that does not fit.
    @Test("Folding preserves the total and the entry count")
    func foldingKeepsEverything() {
        let many = entries((1...12).map { ("Category \($0)", Decimal($0)) })
        let shares = CategoryBreakdown.ranked(many, otherLabel: "Other")

        #expect(CategoryBreakdown.total(shares) == 78)  // 1...12 summed
        #expect(shares.reduce(0) { $0 + $1.count } == 12)
    }

    @Test("Exactly the cap many categories are all kept")
    func keepsExactlyTheCap() {
        let six = entries((1...CategoryBreakdown.maxSlots).map { ("Category \($0)", Decimal($0)) })
        let shares = CategoryBreakdown.ranked(six, otherLabel: "Other")

        #expect(shares.count == CategoryBreakdown.maxSlots)
        #expect(shares.allSatisfy { !$0.isOther })
    }

    /// Two categories on the same total must not swap places between renders,
    /// or the colours appear to move on their own.
    @Test("Equal totals keep a stable order")
    func stableOnTies() {
        let first = CategoryBreakdown.ranked(entries([("Beta", 50), ("Alpha", 50)]), otherLabel: "Other")
        let second = CategoryBreakdown.ranked(entries([("Alpha", 50), ("Beta", 50)]), otherLabel: "Other")

        #expect(first.map(\.name) == second.map(\.name))
    }

    @Test("Nothing recorded gives nothing to draw")
    func emptyIsEmpty() {
        #expect(CategoryBreakdown.ranked([], otherLabel: "Other").isEmpty)
        #expect(CategoryBreakdown.total([]) == 0)
    }
}
