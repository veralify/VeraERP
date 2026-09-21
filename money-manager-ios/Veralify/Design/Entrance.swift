import SwiftUI

/// Staggered entrance for a stack of cards.
///
/// Everything arriving at once reads as a screenshot; arriving in sequence
/// reads as the screen assembling itself. The delays are small — the point is
/// to imply order, not to make anyone wait.
struct StaggeredAppearance: ViewModifier {
    let index: Int
    var delayStep: Double = 0.07
    var rise: CGFloat = 14

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : rise)
            .onAppear {
                guard !reduceMotion else {
                    hasAppeared = true
                    return
                }
                withAnimation(.smooth(duration: 0.5).delay(Double(index) * delayStep)) {
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

/// Starts the entrance roll once the view is on screen.
struct CountUpOnAppear: ViewModifier {
    @Binding var isRolling: Bool
    var delay: Double = 0.25
    var duration: Double = 0.9

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
