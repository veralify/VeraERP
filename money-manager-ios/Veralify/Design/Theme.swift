import SwiftUI

/// The app's visual language: an OLED-dark surface with vivid "highlighter"
/// accents carrying near-black text.
///
/// Sampled from the reference mockups. Two rules keep it honest in a finance
/// app, where the reference was a project tracker:
///
/// 1. **Accent colour is semantic, never decorative.** The reference gives each
///    project an arbitrary colour. Here, lime means surplus and red means
///    deficit — a shortfall must never be shown on a cheerful card.
/// 2. **Text on an accent is near-black, not white.** Every accent is a light,
///    saturated tone; white text on them fails contrast badly.
enum Theme {
    // Surfaces
    static let background = Color(hex: 0x0E0E10)
    static let surface = Color(hex: 0x18181A)
    static let surfaceElevated = Color(hex: 0x232326)
    static let stroke = Color(hex: 0x2A2A2E)

    // Accents
    static let lime = Color(hex: 0xC6FF54)
    static let blue = Color(hex: 0x59A9FB)
    static let yellow = Color(hex: 0xF2E941)
    static let red = Color(hex: 0xFF4D5A)
    static let green = Color(hex: 0x34D164)

    /// Muted red fill for destructive controls, which sit on the dark surface
    /// rather than on an accent.
    static let redSurface = Color(hex: 0x3A1A1E)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)
    static let textTertiary = Color(hex: 0x636366)
    /// For text and glyphs sitting on top of a vivid accent fill.
    static let onAccent = Color(hex: 0x0C0C0F)

    /// Distinct hues for categories, in fixed order.
    ///
    /// The dashboard colours by meaning (lime surplus, red deficit). A category
    /// chart cannot: "Food" is not good or bad, it just needs telling apart from
    /// "Transport". So these are chosen for separation, and the order is fixed —
    /// a category keeps its colour however the ranking moves.
    ///
    /// Checked rather than eyeballed. The previous set failed on two counts: the
    /// green and the yellow sat at ΔE 14 for normal vision and 6.9 for
    /// protanopia, which is indistinguishable, and three of the six were so
    /// desaturated they read as grey. This set holds ΔE 14.8 for deuteranopia
    /// and 25.0 for normal vision at its worst adjacent pair, against the dark
    /// surface. The red and the green are deliberately far apart in the order
    /// and in lightness, which is what rescues the red-green case. The seventh
    /// goes on the end rather than beside the green, where it would sit at
    /// ΔE 2.5 for deuteranopia; on the end it holds 12.7.
    static let categorical: [Color] = [
        Color(hex: 0x5AA9FB),  // blue
        Color(hex: 0xFFCC33),  // amber
        Color(hex: 0x22C9C0),  // teal
        Color(hex: 0xB57BFF),  // violet
        Color(hex: 0xE85D3C),  // coral
        Color(hex: 0x7BEB8F),  // green
        Color(hex: 0xFF7AB6)   // pink
    ]

    /// Past the last colour, one grey. Never a generated hue — two generated
    /// hues are a pair nobody can tell apart.
    static let categoricalOther = Color(hex: 0x7A7A82)

    static func categorical(_ index: Int) -> Color {
        index < categorical.count ? categorical[index] : categoricalOther
    }

    enum Radius {
        static let pill: CGFloat = 999
        static let card: CGFloat = 20
        static let inner: CGFloat = 14
    }
}

extension Color {
    /// Whether near-black text is legible on this colour.
    ///
    /// The reference design puts dark text on its accents, but that only works
    /// because they are all light, saturated tones. A strong red or deep blue
    /// needs white text instead, so foreground colour is derived from relative
    /// luminance (WCAG) rather than chosen by hand per accent.
    var prefersDarkForeground: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance > 0.45
    }

    /// Legible foreground for text sitting on this colour.
    var readableForeground: Color {
        prefersDarkForeground ? Theme.onAccent : .white
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
