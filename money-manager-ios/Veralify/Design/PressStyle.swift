import SwiftUI

/// Press feedback for every custom control.
///
/// `.buttonStyle(.pressable)` strips SwiftUI's built-in highlight, which left the
/// app with no acknowledgement of a touch at all — the screen only changed once
/// the action had already run. This puts the response back, on a spring rather
/// than a fixed curve so it tracks the finger instead of playing a canned
/// animation. Under Reduce Motion it dims without scaling.
struct PressableStyle: ButtonStyle {
    /// Rows want less than controls; a card shrinking as much as a chip looks
    /// like it is collapsing.
    var scale: CGFloat
    var dimmed: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(scale: CGFloat = 0.97, dimmed: Double = 0.85) {
        self.scale = scale
        self.dimmed = dimmed
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? dimmed : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    /// Controls: chips, icons, keypad keys.
    static var pressable: PressableStyle { PressableStyle() }
    /// Whole rows and cards, which need a gentler shrink to read as one surface.
    static var pressableRow: PressableStyle { PressableStyle(scale: 0.985, dimmed: 0.9) }
}
