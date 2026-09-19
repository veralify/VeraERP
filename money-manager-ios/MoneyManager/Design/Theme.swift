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

    /// Distinct hues for flow destinations.
    ///
    /// The dashboard colours by meaning (lime surplus, red deficit). A Sankey
    /// cannot: several debts would all be red and their ribbons would be
    /// indistinguishable, so destinations are told apart by hue instead.
    static let categorical: [Color] = [
        Color(hex: 0x9FC5F0),
        Color(hex: 0x7FD98C),
        Color(hex: 0xF2D14E),
        Color(hex: 0xF0A0A0),
        Color(hex: 0xB9A6F5),
        Color(hex: 0x6FD6C8)
    ]

    static func categorical(_ index: Int) -> Color {
        categorical[index % categorical.count]
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
