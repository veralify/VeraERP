import SwiftUI

enum AppTheme {
    /// Veralify brand palette. Accent stays constant across appearances;
    /// ink/surface/canvas adapt so the app looks native in both Light and
    /// Dark Mode, per Apple's Human Interface Guidelines.
    static let accent = Color(hex: "DE6C15")
    static let ink = Color(light: "141414", dark: "F2F2F2")
    static let surface = Color(light: "DCDCDC", dark: "232323")
    static let canvas = Color(light: "E8EBEE", dark: "0B0B0C")

    static let premiumGradient = LinearGradient(
        colors: [accent, accent.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [canvas, surface],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Brand-toned gradient used for the logo mark, the assistant "thinking"
    /// glow, and greeting headline text.
    static let sparkleGradient = LinearGradient(
        colors: [accent, ink],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Rounded pill fill used for the user's own message bubble.
    static let userBubble = surface

    /// Fill used for the composer's rounded input field.
    static let composerFill = surface
}

struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func premiumCard() -> some View {
        modifier(PremiumCardModifier())
    }
}

extension Color {
    /// Creates a Color from a hex string like "F84C24" or "#F84C24".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }

    /// Creates a Color that switches hex values automatically between Light
    /// and Dark Mode, matching how system colors behave.
    init(light: String, dark: String) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}
