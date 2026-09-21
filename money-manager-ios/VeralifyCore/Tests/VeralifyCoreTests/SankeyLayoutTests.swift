import Foundation
import Testing
@testable import VeralifyCore

struct SankeyLayoutTests {

    private let tolerance = 0.0001

    @Test("No flows lays out nothing")
    func empty() {
        let result = SankeyLayout.compute(flows: [])
        #expect(result.isEmpty)
        #expect(result.sources.isEmpty)
        #expect(result.targets.isEmpty)
    }

    @Test("A single flow fills the whole column")
    func singleFlow() {
        let result = SankeyLayout.compute(
            flows: [.init(source: "in", target: "out", value: 100)],
            gap: 0.02
        )
        // One node per column means no gaps to subtract.
        let source = try! #require(result.sources.first)
        #expect(abs(source.start - 0) < tolerance)
        #expect(abs(source.end - 1) < tolerance)
        #expect(result.ribbons.count == 1)
    }

    @Test("Node heights are proportional to their totals")
    func proportionalHeights() throws {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "in", target: "a", value: 750),
                .init(source: "in", target: "b", value: 250)
            ],
            gap: 0
        )
        let a = try #require(result.targets.first { $0.id == "a" })
        let b = try #require(result.targets.first { $0.id == "b" })
        #expect(abs(a.height - 0.75) < tolerance)
        #expect(abs(b.height - 0.25) < tolerance)
    }

    @Test("Ribbons stack inside a node without overlapping")
    func ribbonsStack() throws {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "in", target: "a", value: 300),
                .init(source: "in", target: "b", value: 700)
            ],
            gap: 0
        )
        let first = try #require(result.ribbons.first { $0.target == "a" })
        let second = try #require(result.ribbons.first { $0.target == "b" })

        // The second ribbon leaves the source exactly where the first ended.
        #expect(abs(first.sourceEnd - second.sourceStart) < tolerance)
        #expect(first.sourceStart < first.sourceEnd)
        #expect(second.sourceStart < second.sourceEnd)
    }

    @Test("A ribbon's two ends match the share it carries")
    func ribbonEndsMatchShare() throws {
        // "in" sends everything to one target, so its ribbon must span the full
        // height at both ends.
        let result = SankeyLayout.compute(
            flows: [.init(source: "in", target: "out", value: 500)],
            gap: 0
        )
        let ribbon = try #require(result.ribbons.first)
        #expect(abs((ribbon.sourceEnd - ribbon.sourceStart) - 1) < tolerance)
        #expect(abs((ribbon.targetEnd - ribbon.targetStart) - 1) < tolerance)
    }

    @Test("Several sources feeding one target each keep their own proportions")
    func multipleSources() throws {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "salary", target: "rent", value: 600),
                .init(source: "salary", target: "debt", value: 200),
                .init(source: "freelance", target: "rent", value: 200)
            ],
            gap: 0
        )
        let salary = try #require(result.sources.first { $0.id == "salary" })
        let freelance = try #require(result.sources.first { $0.id == "freelance" })
        let rent = try #require(result.targets.first { $0.id == "rent" })

        #expect(abs(salary.height - 0.8) < tolerance)
        #expect(abs(freelance.height - 0.2) < tolerance)
        #expect(abs(rent.height - 0.8) < tolerance)
        #expect(result.ribbons.count == 3)
    }

    @Test("Zero and negative flows are dropped, not drawn as slivers")
    func dropsNonPositiveFlows() {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "in", target: "a", value: 100),
                .init(source: "in", target: "zero", value: 0),
                .init(source: "in", target: "negative", value: -50)
            ],
            gap: 0
        )
        #expect(result.ribbons.count == 1)
        #expect(result.targets.map(\.id) == ["a"])
    }

    @Test("Gaps shrink the bands but never push them past the column")
    func gapsStayInBounds() {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "in", target: "a", value: 100),
                .init(source: "in", target: "b", value: 100),
                .init(source: "in", target: "c", value: 100)
            ],
            gap: 0.1
        )
        let last = result.targets.last!
        #expect(last.end <= 1 + tolerance)
        for band in result.targets {
            #expect(band.start >= -tolerance)
            #expect(band.height > 0)
        }
    }

    @Test("Node order follows first appearance, so callers control it")
    func preservesOrder() {
        let result = SankeyLayout.compute(
            flows: [
                .init(source: "in", target: "z", value: 10),
                .init(source: "in", target: "a", value: 10)
            ],
            gap: 0
        )
        #expect(result.targets.map(\.id) == ["z", "a"])
    }
}
