import SwiftUI

/// Press feedback for every custom control.
///
/// `.buttonStyle(.pressable)` strips SwiftUI's built-in highlight, which left the
/// app with no acknowledgement of a touch at all — the screen only changed once
/// the action had already run. This puts the response back, on a spring rather
/// than a fixed curve so it tracks the finger instead of playing a canned
/// animation.
struct PressableStyle: ButtonStyle {
    /// Rows want less than controls; a card shrinking as much as a pill looks
    /// like it is collapsing.
    var scale: CGFloat = 0.96
    var dimmed: Double = 0.88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? dimmed : 1)
            .animation(.spring(duration: 0.28, bounce: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    /// Controls: pills, icons, keypad keys.
    static var pressable: PressableStyle { PressableStyle() }
    /// Whole rows and cards, which need a gentler shrink to read as one surface.
    static var pressableRow: PressableStyle { PressableStyle(scale: 0.985, dimmed: 0.92) }
}
