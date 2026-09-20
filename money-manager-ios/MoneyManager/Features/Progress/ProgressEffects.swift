import SwiftUI

/// A short burst of specks, thrown when something is completed.
///
/// Deliberately brief and small: celebration that outstays its welcome stops
/// reading as reward and starts reading as an obstacle between the user and
/// the next thing they wanted to do.
struct ParticleBurst: View {
    /// Changing this fires a burst.
    let trigger: Bool
    var tint: Color = Theme.green

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Speck: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: Double
        let size: Double
        let delay: Double
    }

    /// Fixed rather than random per frame, so the burst cannot re-roll mid-flight.
    private let specks: [Speck] = (0..<12).map { index in
        let spread = Double(index) / 12 * 2 * .pi
        return Speck(
            angle: spread + Double.random(in: -0.25...0.25),
            distance: Double.random(in: 22...46),
            size: Double.random(in: 3...6),
            delay: Double.random(in: 0...0.06)
        )
    }

    var body: some View {
        ZStack {
            ForEach(specks) { speck in
                Circle()
                    .fill(tint)
                    .frame(width: speck.size, height: speck.size)
                    .keyframeAnimator(
                        initialValue: SpeckState(),
                        trigger: trigger
                    ) { content, state in
                        content
                            .offset(
                                x: cos(speck.angle) * speck.distance * state.travel,
                                y: sin(speck.angle) * speck.distance * state.travel
                            )
                            .opacity(state.opacity)
                            .scaleEffect(state.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.travel) {
                            LinearKeyframe(0, duration: speck.delay)
                            SpringKeyframe(1, duration: 0.45, spring: .snappy)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(0, duration: speck.delay)
                            LinearKeyframe(1, duration: 0.08)
                            LinearKeyframe(0, duration: 0.34)
                        }
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(0.4, duration: speck.delay)
                            SpringKeyframe(1, duration: 0.2)
                            LinearKeyframe(0.5, duration: 0.25)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        // Nothing here conveys information, so it simply does not run.
        .opacity(reduceMotion ? 0 : 1)
    }

    private struct SpeckState {
        var travel: Double = 0
        var opacity: Double = 0
        var scale: Double = 0.4
    }
}

/// Ring showing how much of today is done, as in the reference's "1/5" dial.
struct CompletionRing: View {
    let completed: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceElevated, lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .animation(.smooth(duration: 0.4), value: fraction)
        .accessibilityHidden(true)
    }
}

/// XP track with the level's checkpoints marked, so progress reads as steps
/// rather than an unbroken bar.
struct MilestoneTrack: View {
    /// 0...1 within the current level.
    let fraction: Double
    /// XP values of each checkpoint, in order.
    let milestones: [Int]
    let floor: Int
    let ceiling: Int

    private func position(of milestone: Int) -> Double {
        let span = Double(ceiling - floor)
        guard span > 0 else { return 0 }
        return min(max(Double(milestone - floor) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceElevated).frame(height: 8)

                Capsule()
                    .fill(Theme.lime)
                    .frame(width: max(8, width * min(max(fraction, 0), 1)), height: 8)

                ForEach(milestones, id: \.self) { milestone in
                    let at = position(of: milestone)
                    let reached = fraction >= at
                    Circle()
                        .fill(reached ? Theme.lime : Theme.surfaceElevated)
                        .frame(width: 16, height: 16)
                        .overlay {
                            if reached {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(Theme.onAccent)
                            } else {
                                Circle().strokeBorder(Theme.stroke, lineWidth: 1)
                            }
                        }
                        .offset(x: at * (width - 16))
                }
            }
            .frame(height: 16)
        }
        .frame(height: 16)
        .animation(.smooth(duration: 0.5), value: fraction)
    }
}


/// Blur-and-fade used when a completed quest leaves the list.
///
/// A plain fade reads as the row being hidden; blurring as it goes reads as it
/// dissolving, which is what makes the completion feel like a result rather
/// than a disappearance.
struct DissolveTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 10)
            .scaleEffect(phase.isIdentity ? 1 : 0.94, anchor: .leading)
    }
}

extension AnyTransition {
    static var dissolve: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: AnyTransition(DissolveTransition())
        )
    }
}
