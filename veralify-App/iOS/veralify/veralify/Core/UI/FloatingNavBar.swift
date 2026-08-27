import SwiftUI

struct FloatingNavBar: View {
    @Binding var selection: AppTab
    let createAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.track)
            createButton
            tabButton(.connect)
            tabButton(.profile)
        }
        .padding(.horizontal, VeraTokens.Spacing._2)
        .padding(.vertical, VeraTokens.Spacing._2)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(VeraTokens.Colors.glassBorder, lineWidth: VeraTokens.Borders.`default`))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        .padding(.horizontal, VeraTokens.Spacing._5)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button { selection = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selection == tab ? VeraTokens.Colors.primary : VeraTokens.Colors.fgMuted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.title))
    }

    private var createButton: some View {
        Button(action: createAction) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(VeraTokens.Colors.onPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(VeraTokens.Colors.primary.gradient))
                .overlay(Circle().stroke(VeraTokens.Colors.glassBorder, lineWidth: VeraTokens.Borders.`default`))
                .shadow(color: VeraTokens.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create")
    }
}

enum AppTab: CaseIterable, Identifiable {
    case home
    case track
    case connect
    case profile

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .track: return "Track"
        case .connect: return "Connect"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .track: return "chart.line.uptrend.xyaxis"
        case .connect: return "person.2.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}
