import SwiftUI

enum AppTheme {
    @available(*, deprecated, message: "Use VeraTokens.Colors.primary or coachAccent directly.")
    static let accent = VeraTokens.Colors.primary
    @available(*, deprecated, message: "Use VeraTokens.Colors.fg directly.")
    static let ink = VeraTokens.Colors.fg
    @available(*, deprecated, message: "Use VeraTokens.Colors.surfaceMuted directly.")
    static let surface = VeraTokens.Colors.surfaceMuted
    @available(*, deprecated, message: "Use VeraTokens.Colors.bg directly.")
    static let canvas = VeraTokens.Colors.bg

    static let premiumGradient = LinearGradient(
        colors: [VeraTokens.Colors.primary, VeraTokens.Colors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [VeraTokens.Colors.bg, VeraTokens.Colors.bgSubtle],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sparkleGradient = LinearGradient(
        colors: [VeraTokens.Colors.primary, VeraTokens.Colors.accent],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let userBubble = VeraTokens.Colors.surfaceMuted
    static let composerFill = VeraTokens.Colors.surface
}

struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(VeraTokens.Spacing._4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: VeraTokens.Radii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VeraTokens.Radii.lg, style: .continuous)
                    .stroke(VeraTokens.Colors.glassBorder, lineWidth: VeraTokens.Borders.`default`)
            )
    }
}

extension View {
    func premiumCard() -> some View {
        modifier(PremiumCardModifier())
    }
}
