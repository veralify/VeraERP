import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.39, green: 0.36, blue: 1.0)

    static let premiumGradient = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.24, blue: 0.98),
            Color(red: 0.51, green: 0.29, blue: 0.96),
            Color(red: 0.15, green: 0.77, blue: 0.93)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
        startPoint: .top,
        endPoint: .bottom
    )
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
