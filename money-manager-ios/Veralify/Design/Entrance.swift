import SwiftUI

/// Staggered entrance for a stack of cards.
///
/// Everything arriving at once reads as a screenshot; arriving in sequence
/// reads as the screen assembling itself. The delays are small — the point is
/// to imply order, not to make anyone wait. Under Reduce Motion the cards
/// only fade in, together, without rising.
struct StaggeredAppearance: ViewModifier {
    let index: Int
    var delayStep: Double
    var rise: CGFloat

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(index: Int, delayStep: Double = Theme.Motion.staggerStep, rise: CGFloat = Theme.Motion.entranceRise) {
        self.index = index
        self.delayStep = delayStep
        self.rise = rise
    }

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : rise)
            .onAppear {
                guard !hasAppeared else { return }
                guard !reduceMotion else {
                    withAnimation(Theme.Motion.reduced) { hasAppeared = true }
                    return
                }
                withAnimation(Theme.Motion.entrance.delay(Double(index) * delayStep)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// `index` is the card's position in the stack, from zero.
    func staggeredAppearance(_ index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }

    /// `.animation(_:value:)` that swaps the given animation for a short
    /// cross-fade when Reduce Motion is on. Use it instead of `.animation`.
    func themeAnimation<V: Equatable>(_ animation: Animation = Theme.Motion.standard, value: V) -> some View {
        modifier(ThemeAnimation(animation: animation, value: value))
    }
}

/// Backs `.themeAnimation(_:value:)`.
struct ThemeAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(animation: Animation, value: V) {
        self.animation = animation
        self.value = value
    }

    func body(content: Content) -> some View {
        content.animation(Theme.Motion.adaptive(animation, reduceMotion: reduceMotion), value: value)
    }
}

/// Counts a number through its intermediate values.
///
/// A `Bool` flipped inside `withAnimation` is no use here: the state changes
/// immediately and only *animatable* properties interpolate, so a `Text` jumps
/// straight to its final value — `.delay()` included. Conforming the view
/// itself to `Animatable` makes SwiftUI interpolate `value` and rebuild the
/// body each frame, which is what actually produces a count.
struct RollingNumber<Content: View>: View, Animatable {
    var value: Double
    @ViewBuilder var content: (Double) -> Content

    // `View` is main-actor isolated but SwiftUI interpolates off it, so the
    // conformance has to opt out explicitly under strict concurrency.
    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        content(value)
    }
}

/// Starts the entrance roll once the view is on screen. Under Reduce Motion
/// the number simply appears at its value.
struct CountUpOnAppear: ViewModifier {
    @Binding var isRolling: Bool
    var delay: Double = 0.25
    var duration: Double = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.onAppear {
            guard !isRolling else { return }
            guard !reduceMotion else {
                isRolling = true
                return
            }
            withAnimation(.smooth(duration: duration).delay(delay)) {
                isRolling = true
            }
        }
    }
}

extension View {
    func countUpOnAppear(_ isRolling: Binding<Bool>, delay: Double = 0.25) -> some View {
        modifier(CountUpOnAppear(isRolling: isRolling, delay: delay))
    }
}
