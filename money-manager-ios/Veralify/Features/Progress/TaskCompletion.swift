import SwiftUI

/// The tick, drawn rather than switched on.
///
/// Swapping one glyph for another announces a result; drawing the stroke shows
/// it happening, which is the difference the reference is trading on.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.70))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.32))
        return path
    }
}

/// The circular control on a task row: dashed while outstanding, filled with a
/// drawn tick once complete, with a short pop and a particle burst on the
/// moment of completion.
struct CompletionButton: View {
    let isComplete: Bool
    /// Increments when this row is completed.
    ///
    /// A counter rather than a flag because `keyframeAnimator` only runs when a
    /// view that is *already mounted* sees its trigger change. Creating the
    /// effect at the moment of completion leaves it stuck on its first
    /// keyframe — invisible — so the effects stay mounted and this changes.
    let celebrationID: Int
    var accent: Color = Theme.green
    var isInteractive: Bool = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Pop {
        var scale: Double = 1
    }

    var body: some View {
        Group {
            if isInteractive {
                Button(action: action) { face }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isComplete ? "Completed" : "Mark as done")
                    .accessibilityAddTraits(isComplete ? [.isButton, .isSelected] : .isButton)
            } else {
                // Derived state, not a control.
                face.accessibilityHidden(true)
            }
        }
    }

    private var face: some View {
        ZStack {
            if isComplete {
                Circle().fill(accent)
                CheckmarkShape()
                    .trim(from: 0, to: isComplete ? 1 : 0)
                    .stroke(
                        Theme.onAccent,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 26, height: 26)
                    // The draw is the point, so it gets its own timing rather
                    // than inheriting the row's.
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.32).delay(0.06),
                        value: isComplete
                    )
            } else {
                // An outstanding task reads as a slot waiting to be filled.
                Circle()
                    .strokeBorder(
                        Theme.textTertiary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3.5, 3.5])
                    )
            }
        }
        .frame(width: 26, height: 26)
        .keyframeAnimator(initialValue: Pop(), trigger: celebrationID) { content, pop in
            content.scaleEffect(reduceMotion ? 1 : pop.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.15, duration: 0.16, spring: .snappy)
                SpringKeyframe(0.95, duration: 0.14, spring: .snappy)
                SpringKeyframe(1.00, duration: 0.20, spring: .bouncy)
            }
        }
        // Always mounted; invisible until its trigger changes.
        .overlay { ParticleBurst(trigger: celebrationID, tint: accent) }
        // The minimum touch target. The circle stays 26pt; this is only the
        // area around it that takes the tap.
        .frame(width: 44, height: 44)
        .contentShape(.rect)
    }
}

/// "+25 XP" rising away from the task it was earned on.
struct FloatingReward: View {
    let text: String
    /// Increments to fire. See `CompletionButton.celebrationID`.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Drift {
        var offset: Double = 0
        var opacity: Double = 0
        var scale: Double = 0.8
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Theme.lime)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.lime.opacity(0.16), in: .capsule)
            .keyframeAnimator(initialValue: Drift(), trigger: trigger) { content, drift in
                content
                    .offset(y: drift.offset)
                    .opacity(drift.opacity)
                    .scaleEffect(drift.scale)
            } keyframes: { _ in
                KeyframeTrack(\.offset) {
                    LinearKeyframe(0, duration: 0.02)
                    SpringKeyframe(-42, duration: 0.72, spring: .smooth)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 0.02)
                    LinearKeyframe(1, duration: 0.12)
                    LinearKeyframe(1, duration: 0.30)
                    LinearKeyframe(0, duration: 0.30)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.8, duration: 0.02)
                    SpringKeyframe(1.05, duration: 0.18, spring: .bouncy)
                    LinearKeyframe(1, duration: 0.54)
                }
            }
            // The label is shown in an overlay on a 44pt button, which would
            // otherwise squeeze it to that width and truncate it to an ellipsis.
            .fixedSize()
            .allowsHitTesting(false)
            // It repeats information the row already shows, so it is decoration.
            .accessibilityHidden(true)
            .opacity(reduceMotion ? 0 : 1)
    }
}

/// The larger moment when a completion crosses a level threshold.
struct LevelUpBanner: View {
    let level: Int
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Entrance {
        var scale: Double = 0.7
        var opacity: Double = 0
        var lift: Double = 12
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .bold))
            Text("Level \(level)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.lime.readableForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.lime, in: .capsule)
        .shadow(color: Theme.lime.opacity(0.5), radius: 18, y: 6)
        .keyframeAnimator(initialValue: Entrance(), trigger: trigger) { content, entrance in
            content
                .scaleEffect(reduceMotion ? 1 : entrance.scale)
                .opacity(entrance.opacity)
                .offset(y: reduceMotion ? 0 : entrance.lift)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.08, duration: 0.26, spring: .bouncy)
                LinearKeyframe(1, duration: 0.9)
                LinearKeyframe(0.96, duration: 0.3)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.18)
                LinearKeyframe(1, duration: 1.0)
                LinearKeyframe(0, duration: 0.28)
            }
            KeyframeTrack(\.lift) {
                SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                LinearKeyframe(0, duration: 1.16)
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Reached level \(level)")
    }
}
