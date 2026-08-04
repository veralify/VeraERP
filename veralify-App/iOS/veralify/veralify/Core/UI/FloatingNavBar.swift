import SwiftUI

/// Floating pill-shaped bottom navigation bar. Replaces the old hamburger
/// side drawer with a single persistent surface for switching between the
/// app's main destinations, similar to modern AI-assistant apps.
struct FloatingNavBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: { selection = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.titleKey)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.titleKey))
            }
        }
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 20)
    }
}

enum AppTab: CaseIterable, Identifiable {
    case home
    case explore
    case films
    case esims
    case profile

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home:    return "Home"
        case .explore: return "Explore"
        case .films:   return "Films"
        case .esims:   return "My eSIMs"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home:    return "house.fill"
        case .explore: return "globe"
        case .films:   return "camera.aperture"
        case .esims:   return "simcard.2.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}
