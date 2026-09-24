import Foundation

/// Lays out weighted circles in a rectangle without overlapping them.
///
/// Pure geometry, and deliberately not a physics simulation: a bubble that
/// settles somewhere new on every launch is a dashboard you have to re-read
/// each time. The same inputs give the same picture, so the eye learns where
/// its own debts live and the layout can be tested without a screen.
public enum BubblePacking {

    public struct Item: Sendable, Equatable {
        public let id: Int
        /// What the bubble is worth. Area is proportional to it, so a debt
        /// twice the size looks twice the size — a radius proportional to the
        /// value would look four times it.
        public let weight: Decimal

        public init(id: Int, weight: Decimal) {
            self.id = id
            self.weight = weight
        }
    }

    public struct Placement: Sendable, Equatable {
        public let id: Int
        public let x: Double
        public let y: Double
        public let radius: Double
    }

    /// Places every item, biggest first, in the first free spot spiralling out
    /// from the middle.
    ///
    /// - Parameters:
    ///   - items: what to place. Items weighing nothing are dropped — a circle
    ///     of radius zero is a bug on screen, not a small bubble.
    ///   - size: the canvas, in points.
    ///   - fill: how much of the canvas the circles may cover in total. Packing
    ///     circles cannot exceed ~0.9 even in theory, and a dashboard wants air.
    ///   - spacing: the gap left between two touching circles.
    ///   - anchored: ids that belong at a fixed spot, given in fractions of
    ///     the canvas. They are placed first and everything else packs around
    ///     them, so an anchored circle keeps its corner without being sat on.
    public static func layout(
        items: [Item],
        size: (width: Double, height: Double),
        fill: Double = 0.42,
        spacing: Double = 10,
        minRadius: Double = 0,
        anchored: [Int: (x: Double, y: Double)] = [:]
    ) -> [Placement] {
        let usable = items.filter { $0.weight > 0 }
        guard !usable.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let weights = usable.map { NSDecimalNumber(decimal: $0.weight).doubleValue }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }

        // Two bubbles can each fit the canvas on their own and still have
        // nowhere to stand together — the second needs to clear the first AND
        // stay inside the bounds, and on a narrow canvas no point does both.
        // The answer is to draw everything smaller, not to give up and stack
        // them: a bubble hidden under another is a debt the user cannot see.
        var attempt = fill
        for _ in 0..<12 {
            if let placed = attemptLayout(
                usable, weights: weights, total: total,
                size: size, fill: attempt, spacing: spacing,
                minRadius: minRadius, anchored: anchored
            ) {
                return placed
            }
            attempt *= 0.85
        }

        // Nothing packs even at a twelfth of the area asked for, which means
        // the canvas is too small for the number of bubbles. Lay them out
        // overlapping rather than returning an empty screen.
        return attemptLayout(
            usable, weights: weights, total: total,
            size: size, fill: attempt, spacing: spacing,
            minRadius: minRadius, anchored: anchored, allowOverlap: true
        ) ?? []
    }

    /// One pass at a given size. Returns nil the moment a bubble has nowhere
    /// to go, so the caller can try again smaller.
    private static func attemptLayout(
        _ items: [Item],
        weights: [Double],
        total: Double,
        size: (width: Double, height: Double),
        fill: Double,
        spacing: Double,
        minRadius: Double = 0,
        anchored: [Int: (x: Double, y: Double)] = [:],
        allowOverlap: Bool = false
    ) -> [Placement]? {
        // Area per unit of weight, from the budget the caller allows.
        let scale = size.width * size.height * fill / total

        let sized = zip(items, weights)
            .map { (item: $0.0, radius: (scale * $0.1 / .pi).squareRoot()) }
            .sorted { $0.radius > $1.radius }

        // A single bubble cannot be wider than the canvas, however much of the
        // total it is owed.
        let ceiling = min(size.width, size.height) / 2 - spacing
        let floor = min(minRadius, ceiling)
        let capped = sized.map {
            (item: $0.item, radius: min(max($0.radius, floor), ceiling))
        }

        let centre = (x: size.width / 2, y: size.height / 2)
        var placed: [Placement] = []

        // Anchored circles prefer their spot but yield to each other: an
        // anchor is where the user wants a bubble, not a hard coordinate two
        // of them can share. Placing them exactly let a dragged bubble and the
        // add button land on the same corner, and when the rest could not pack
        // around the overlap the whole board collapsed to the centre.
        //
        // Higher priority first (the add button is given the lowest), so user
        // intent keeps its spot and the furniture moves aside.
        let anchoredEntries = capped
            .filter { anchored[$0.item.id] != nil }
            .sorted { anchorPriority($0.item.id) > anchorPriority($1.item.id) }

        for entry in anchoredEntries {
            guard let anchor = anchored[entry.item.id] else { continue }
            let preferred = (
                x: min(max(anchor.x * size.width, entry.radius), size.width - entry.radius),
                y: min(max(anchor.y * size.height, entry.radius), size.height - entry.radius)
            )
            let clear = placed.allSatisfy { other in
                hypot(other.x - preferred.x, other.y - preferred.y) >= other.radius + entry.radius + spacing
            }
            // Its own spot if free, otherwise the nearest free spot to it.
            let spot = clear
                ? preferred
                : freeSpot(radius: entry.radius, around: preferred, within: size, avoiding: placed, spacing: spacing)
                    ?? preferred
            placed.append(Placement(id: entry.item.id, x: spot.x, y: spot.y, radius: entry.radius))
        }

        for entry in capped where anchored[entry.item.id] == nil {
            let spot = freeSpot(
                radius: entry.radius,
                around: centre,
                within: size,
                avoiding: placed,
                spacing: spacing
            )
            guard let spot else {
                if allowOverlap {
                    placed.append(
                        Placement(id: entry.item.id, x: centre.x, y: centre.y, radius: entry.radius)
                    )
                    continue
                }
                return nil
            }
            placed.append(
                Placement(id: entry.item.id, x: spot.x, y: spot.y, radius: entry.radius)
            )
        }

        return placed
    }

    /// Anchors are honoured highest-first. The add button uses the sentinel
    /// -3 and is pinned lowest, so a bubble dragged next to it wins the spot
    /// and the button steps aside.
    private static func anchorPriority(_ id: Int) -> Int { id == -3 ? -1 : 0 }

    /// Walks a spiral out from the middle and returns the first point where the
    /// circle touches nothing.
    ///
    /// The step is a fraction of the circle being placed rather than a fixed
    /// number of points, so a small bubble searches finely and a large one does
    /// not crawl.
    private static func freeSpot(
        radius: Double,
        around centre: (x: Double, y: Double),
        within size: (width: Double, height: Double),
        avoiding placed: [Placement],
        spacing: Double
    ) -> (x: Double, y: Double)? {
        func fits(_ x: Double, _ y: Double) -> Bool {
            guard x - radius >= 0, x + radius <= size.width,
                  y - radius >= 0, y + radius <= size.height
            else { return false }

            return placed.allSatisfy { other in
                let dx = other.x - x
                let dy = other.y - y
                return (dx * dx + dy * dy).squareRoot() >= other.radius + radius + spacing
            }
        }

        if fits(centre.x, centre.y) { return centre }

        let step = max(radius / 4, 3)
        // The golden angle spreads successive samples evenly instead of
        // stacking them along spokes.
        let turn = Double.pi * (3 - 5.0.squareRoot())
        let reach = (size.width * size.width + size.height * size.height).squareRoot()

        var index = 1
        while true {
            let distance = step * Double(index).squareRoot()
            if distance > reach { break }

            let angle = Double(index) * turn
            let x = centre.x + distance * cos(angle)
            let y = centre.y + distance * sin(angle)
            if fits(x, y) { return (x, y) }
            index += 1
        }

        return nil
    }
}
