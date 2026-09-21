import Foundation

/// Geometry for a two-column Sankey diagram.
///
/// Pure maths, deliberately free of any drawing framework: it returns
/// normalised 0...1 positions that a view scales into its own bounds. That
/// keeps the part that is easy to get wrong — proportionality and stacking —
/// testable in milliseconds.
public enum SankeyLayout {

    public struct Flow: Sendable, Hashable {
        public let source: String
        public let target: String
        public let value: Decimal

        public init(source: String, target: String, value: Decimal) {
            self.source = source
            self.target = target
            self.value = value
        }
    }

    /// A node's vertical extent within its column, normalised to 0...1.
    public struct Band: Sendable, Hashable, Identifiable {
        public let id: String
        public let start: Double
        public let end: Double
        public let value: Decimal
        public var height: Double { end - start }
    }

    /// A ribbon joining a source band to a target band. The four edges are
    /// normalised, so a view can draw the curve at any size.
    public struct Ribbon: Sendable, Hashable, Identifiable {
        public let id: String
        public let source: String
        public let target: String
        public let value: Decimal
        public let sourceStart: Double
        public let sourceEnd: Double
        public let targetStart: Double
        public let targetEnd: Double
    }

    public struct Result: Sendable {
        public let sources: [Band]
        public let targets: [Band]
        public let ribbons: [Ribbon]
        public var isEmpty: Bool { ribbons.isEmpty }
    }

    /// Lays out `flows` into two columns.
    ///
    /// - Parameter gap: fraction of the column reserved as spacing *in total*,
    ///   split evenly between the gaps. Clamped to 0..<1.
    ///
    /// Node order follows first appearance in `flows`, so the caller controls
    /// it. Non-positive flows are dropped — a zero-width ribbon is noise, and a
    /// negative one is meaningless here.
    public static func compute(flows: [Flow], gap: Double = 0.02) -> Result {
        let usable = flows.filter { $0.value > 0 }
        guard !usable.isEmpty else {
            return Result(sources: [], targets: [], ribbons: [])
        }

        let total = usable.reduce(Decimal(0)) { $0 + $1.value }
        guard total > 0 else { return Result(sources: [], targets: [], ribbons: []) }

        let sourceIDs = orderedIDs(usable.map(\.source))
        let targetIDs = orderedIDs(usable.map(\.target))

        let sourceBands = bands(ids: sourceIDs, flows: usable, total: total, gap: gap, keyPath: \.source)
        let targetBands = bands(ids: targetIDs, flows: usable, total: total, gap: gap, keyPath: \.target)

        // Ribbons stack inside each node in flow order, so the offsets are
        // tracked per node as we go.
        var sourceCursor = Dictionary(uniqueKeysWithValues: sourceBands.map { ($0.id, $0.start) })
        var targetCursor = Dictionary(uniqueKeysWithValues: targetBands.map { ($0.id, $0.start) })

        var ribbons: [Ribbon] = []
        for (index, flow) in usable.enumerated() {
            guard let sourceBand = sourceBands.first(where: { $0.id == flow.source }),
                  let targetBand = targetBands.first(where: { $0.id == flow.target }),
                  let sourceStart = sourceCursor[flow.source],
                  let targetStart = targetCursor[flow.target]
            else { continue }

            let share = double(flow.value) / double(total)
            let sourceHeight = sourceBand.height * (share / (double(sourceBand.value) / double(total)))
            let targetHeight = targetBand.height * (share / (double(targetBand.value) / double(total)))

            ribbons.append(
                Ribbon(
                    id: "\(flow.source)→\(flow.target)#\(index)",
                    source: flow.source,
                    target: flow.target,
                    value: flow.value,
                    sourceStart: sourceStart,
                    sourceEnd: sourceStart + sourceHeight,
                    targetStart: targetStart,
                    targetEnd: targetStart + targetHeight
                )
            )
            sourceCursor[flow.source] = sourceStart + sourceHeight
            targetCursor[flow.target] = targetStart + targetHeight
        }

        return Result(sources: sourceBands, targets: targetBands, ribbons: ribbons)
    }

    private static func bands(
        ids: [String],
        flows: [Flow],
        total: Decimal,
        gap: Double,
        keyPath: KeyPath<Flow, String>
    ) -> [Band] {
        let clampedGap = min(max(gap, 0), 0.9)
        // Gaps live between nodes, so n nodes have n-1 of them.
        let gapCount = max(ids.count - 1, 0)
        let gapEach = gapCount > 0 ? clampedGap / Double(gapCount) : 0
        let available = 1 - clampedGap * (gapCount > 0 ? 1 : 0)

        var cursor = 0.0
        var result: [Band] = []
        for id in ids {
            let value = flows.filter { $0[keyPath: keyPath] == id }.reduce(Decimal(0)) { $0 + $1.value }
            let height = available * (double(value) / double(total))
            result.append(Band(id: id, start: cursor, end: cursor + height, value: value))
            cursor += height + gapEach
        }
        return result
    }

    private static func orderedIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func double(_ value: Decimal) -> Double {
        (value as NSDecimalNumber).doubleValue
    }
}
