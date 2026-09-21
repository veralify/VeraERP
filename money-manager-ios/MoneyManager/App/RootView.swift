import SwiftUI
import SwiftData

/// Decides between first-run setup and the app proper.
struct RootView: View {
    /// Survives a store reset, so a returning user is not sent back through
    /// setup after clearing data. Onboarding writes the flag only on completion.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                NavigationStack {
                    MainTabView()
                        .navigationDestination(for: EntryKind.self) { kind in
                            EntryListView(kind: kind)
                        }
                        .navigationDestination(for: FamilyRoute.self) { _ in
                            FamilyView()
                        }
                }
            } else {
                OnboardingView { hasCompletedOnboarding = true }
            }
        }
        .tint(Theme.lime)
        // The design is dark-only: its accents are light, saturated tones that
        // carry near-black text and have no light-mode counterpart yet.
        .preferredColorScheme(.dark)
    }
}
