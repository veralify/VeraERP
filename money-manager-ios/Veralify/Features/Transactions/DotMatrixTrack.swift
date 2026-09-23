import SwiftUI

/// A grid of small squares with a band of light travelling across it.
///
/// The track behind the swipe control used to be a flat capsule, which said
/// nothing until the knob moved over it. The grid gives the bar a texture that
/// is alive before the gesture starts, so the control reads as something you
/// are meant to act on rather than a coloured bar.
///
/// Drawn in a `Canvas` rather than as a few hundred `Rectangle` views: at
/// roughly 40 by 4 cells this is around 160 shapes, redrawn every frame of the
/// shimmer, which is a lot of view identity for something that is pure paint.
struct DotMatrixTrack: View {
    /// Tints the lit cells. Green for money in, red for money out.
    let accent: Color
    /// How much of the track the drag has claimed, 0...1. Cells behind the
    /// knob burn at full strength; the rest only catch the travelling band.
    var progress: Double = 0
    var isAnimated: Bool = true

    private let cell: Double = 7
    private let gap: Double = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimated)) { timeline in
            Canvas { context, size in
                let pitch = cell + gap
                let columns = max(Int(size.width / pitch), 1)
                let rows = max(Int(size.height / pitch), 1)

                // Centre the grid in whatever is left over after whole cells.
                let insetX = (size.width - Double(columns) * pitch + gap) / 2
                let insetY = (size.height - Double(rows) * pitch + gap) / 2

                let time = timeline.date.timeIntervalSinceReferenceDate

                /// A sweep of light crossing the grid, as a 0...1 strength.
                ///
                /// Two of these at different speeds and widths, running in
                /// opposite directions, is what stops the track looking like
                /// one animation on a loop: the pair drift in and out of step
                /// and never repeat inside a glance.
                func sweep(period: Double, width: Double, reversed: Bool, at across: Double) -> Double {
                    guard isAnimated else { return 0 }
                    let phase = (time.truncatingRemainder(dividingBy: period) / period)
                    let travel = phase * (1 + width * 2) - width
                    let head = reversed ? 1 - travel : travel
                    let distance = abs(across - head)
                    return distance < width ? pow(1 - distance / width, 2) : 0
                }

                for column in 0..<columns {
                    let across = Double(column) / Double(max(columns - 1, 1))
                    let isLit = across <= progress

                    let first = sweep(period: 2.2, width: 0.26, reversed: false, at: across)
                    let second = sweep(period: 3.7, width: 0.16, reversed: true, at: across)

                    for row in 0..<rows {
                        // A little vertical lag so a band leans rather than
                        // landing as a straight column.
                        let lean = Double(row) * 0.05
                        let band = max(0, first - lean) + max(0, second - lean * 0.6) * 0.7

                        // Each cell keeps its own slow pulse, seeded from where
                        // it sits, so the grid breathes between sweeps instead
                        // of going flat. Deterministic: the same cell always
                        // twinkles at the same moment.
                        let seed = Double((column &* 73 &+ row &* 151) % 97) / 97
                        let twinkle = isAnimated
                            ? pow(0.5 + 0.5 * sin(time * 1.1 + seed * 2 * .pi), 6)
                            : 0

                        let glow = min(band + twinkle * 0.5, 1.4)
                        // A low resting floor and a steep climb: a bright
                        // accent held at middling opacity over a dark surface
                        // reads as mud (lime goes olive), so the dim cells sit
                        // well back and the lit ones carry the colour.
                        let strength = isLit ? 0.88 + 0.12 * glow : 0.09 + 0.82 * glow

                        // Bright cells grow a touch and wash toward white, so
                        // a peak reads as a spark rather than a darker square.
                        let peak = max(0, min(glow, 1))
                        let grow = cell * 0.22 * peak
                        let rect = CGRect(
                            x: insetX + Double(column) * pitch - grow / 2,
                            y: insetY + Double(row) * pitch - grow / 2,
                            width: cell + grow,
                            height: cell + grow
                        )

                        let tint = accent.mix(with: .white, by: 0.38 * peak)
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1.5 + grow / 2),
                            with: .color(tint.opacity(min(strength, 1)))
                        )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
