import Testing
import Foundation
@testable import VeralifyCore

@Suite("Bubble packing")
struct BubblePackingTests {

    private let canvas = (width: 360.0, height: 560.0)

    private func layout(_ weights: [Decimal], fill: Double = 0.42) -> [BubblePacking.Placement] {
        BubblePacking.layout(
            items: weights.enumerated().map { .init(id: $0.offset, weight: $0.element) },
            size: canvas,
            fill: fill
        )
    }

    @Test("Every bubble is placed")
    func placesEveryone() {
        #expect(layout([100, 200, 50, 400, 25]).count == 5)
    }

    /// The one thing a packing must do.
    @Test("No two bubbles overlap")
    func noOverlap() {
        let placed = layout([900, 400, 400, 200, 120, 90, 60, 30])

        for (index, a) in placed.enumerated() {
            for b in placed[(index + 1)...] {
                let distance = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
                #expect(
                    distance >= a.radius + b.radius - 0.001,
                    "\(a.id) and \(b.id) overlap by \(a.radius + b.radius - distance)"
                )
            }
        }
    }

    @Test("Every bubble stays on the canvas")
    func staysInBounds() {
        for placement in layout([500, 300, 200, 100, 60]) {
            #expect(placement.x - placement.radius >= -0.001)
            #expect(placement.y - placement.radius >= -0.001)
            #expect(placement.x + placement.radius <= canvas.width + 0.001)
            #expect(placement.y + placement.radius <= canvas.height + 0.001)
        }
    }

    /// Area, not radius. A debt twice the size should look twice the size, and
    /// scaling the radius instead would make it look four times the size.
    @Test("Twice the weight is twice the area")
    func areaTracksWeight() throws {
        let placed = layout([200, 100])
        let big = try #require(placed.first { $0.id == 0 })
        let small = try #require(placed.first { $0.id == 1 })

        let ratio = (big.radius * big.radius) / (small.radius * small.radius)
        #expect(abs(ratio - 2) < 0.01)
    }

    @Test("The biggest bubble takes the middle")
    func biggestIsCentred() throws {
        let placed = layout([50, 900, 50])
        let biggest = try #require(placed.max { $0.radius < $1.radius })

        #expect(abs(biggest.x - canvas.width / 2) < 0.001)
        #expect(abs(biggest.y - canvas.height / 2) < 0.001)
    }

    /// A zero-weight bubble would be a dot, which reads as a rendering fault.
    @Test("Weightless items are dropped, not drawn as dots")
    func dropsZeroWeights() {
        let placed = layout([100, 0, 50, -10])
        #expect(placed.count == 2)
        #expect(placed.allSatisfy { $0.radius > 0 })
    }

    @Test("An empty list lays out nothing rather than crashing")
    func handlesEmpty() {
        #expect(layout([]).isEmpty)
        #expect(BubblePacking.layout(items: [], size: (0, 0)).isEmpty)
    }

    /// One debt asked to fill the screen must still fit on it.
    @Test("A lone bubble is capped to the canvas")
    func capsTheLoneBubble() throws {
        let placed = BubblePacking.layout(
            items: [.init(id: 1, weight: 1_000_000)], size: canvas, fill: 0.95
        )
        let only = try #require(placed.first)
        #expect(only.radius <= min(canvas.width, canvas.height) / 2)
    }

    /// The real board, at the size the phone actually gives it.
    ///
    /// Two large bubbles on a narrow canvas is the case that broke: each fits
    /// on its own, but the second cannot be both clear of the first and inside
    /// the bounds, so it was dropped in the middle on top of it.
    @Test("Two large bubbles on a narrow canvas still separate")
    func shrinksRatherThanOverlapping() {
        let narrow = (width: 360.0, height: 470.0)
        let placed = BubblePacking.layout(
            items: [500, 429.25, 315.75, 300, 105, 100].enumerated()
                .map { .init(id: $0.offset, weight: $0.element) },
            size: narrow
        )

        #expect(placed.count == 6)
        for (index, a) in placed.enumerated() {
            for b in placed[(index + 1)...] {
                let distance = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
                #expect(
                    distance >= a.radius + b.radius - 0.001,
                    "\(a.id) and \(b.id) overlap by \(a.radius + b.radius - distance)"
                )
            }
        }
    }

    /// The case that actually shipped broken: after moving €210 onto a debt,
    /// the two biggest bubbles were €525.75 and €500 on a phone-width board,
    /// and the second was drawn underneath the first.
    @Test("Two near-equal giants do not stack on the phone board")
    func twoGiantsSeparate() throws {
        let board = (width: 402.0, height: 570.0)
        let placed = BubblePacking.layout(
            items: [525.75, 500, 300, 219.25, 105, 100].enumerated()
                .map { .init(id: $0.offset, weight: $0.element) },
            size: board
        )

        #expect(placed.count == 6)
        let big = try #require(placed.first { $0.id == 0 })
        let second = try #require(placed.first { $0.id == 1 })
        let gap = ((big.x - second.x) * (big.x - second.x)
                 + (big.y - second.y) * (big.y - second.y)).squareRoot()
        #expect(gap >= big.radius + second.radius - 0.001)
    }

    /// The add button holds a corner; the money packs around it.
    @Test("An anchored bubble keeps its corner and is not sat on")
    func anchoredKeepsItsCorner() throws {
        let board = (width: 402.0, height: 570.0)
        let placed = BubblePacking.layout(
            items: [500, 316, 300, 260, 105, 100].enumerated()
                .map { .init(id: $0.offset, weight: $0.element) },
            size: board,
            anchored: [3: (x: 0.82, y: 0.86)]
        )

        let pinned = try #require(placed.first { $0.id == 3 })
        // Bottom-right quadrant, and wholly on the canvas.
        #expect(pinned.x > board.width / 2)
        #expect(pinned.y > board.height / 2)
        #expect(pinned.x + pinned.radius <= board.width + 0.001)
        #expect(pinned.y + pinned.radius <= board.height + 0.001)

        for other in placed where other.id != pinned.id {
            let distance = ((pinned.x - other.x) * (pinned.x - other.x)
                          + (pinned.y - other.y) * (pinned.y - other.y)).squareRoot()
            #expect(
                distance >= pinned.radius + other.radius - 0.001,
                "\(other.id) sits on the anchored bubble"
            )
        }
    }

    /// A tiny weight must still be big enough to hold its label.
    @Test("No bubble shrinks below the minimum")
    func honoursMinimumRadius() {
        let placed = BubblePacking.layout(
            items: [1000, 30, 20].enumerated().map { .init(id: $0.offset, weight: $0.element) },
            size: canvas,
            minRadius: 44
        )
        #expect(placed.count == 3)
        #expect(placed.allSatisfy { $0.radius >= 44 - 0.001 })
    }

    /// The floor never makes a bubble wider than the canvas allows.
    @Test("The minimum yields to the canvas ceiling")
    func minimumRespectsCeiling() {
        let small = (width: 120.0, height: 120.0)
        let placed = BubblePacking.layout(
            items: [(1, 100.0)].map { .init(id: $0.0, weight: Decimal($0.1)) },
            size: small,
            minRadius: 999
        )
        #expect(placed.first!.radius <= min(small.width, small.height) / 2)
    }

    /// Same input, same picture — so the eye can learn where its debts live.
    @Test("The layout is stable across runs")
    func isDeterministic() {
        let weights: [Decimal] = [300, 220, 180, 90, 40]
        #expect(layout(weights) == layout(weights))
    }
}
