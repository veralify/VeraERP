import SwiftUI

/// App shell: switches between the four main destinations, with a floating
/// pill-shaped bottom nav bar instead of a system tab bar or side drawer.
struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [String] = []
    @ObservedObject private var navVisibility = NavigationVisibilityTracker.shared
    @EnvironmentObject private var localization: LocalizationManager

    private var isNavBarHidden: Bool {
        navVisibility.pushedScreenCount > 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    ChatHomeView(path: $homePath)
                case .explore:
                    ExploreView()
                case .esims:
                    MyESIMsView()
                case .profile:
                    ProfileView()
                }
            }
            .ignoresSafeArea(.keyboard)
            .id(localization.language)

            if !isNavBarHidden {
                FloatingNavBar(selection: $selectedTab)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isNavBarHidden)
        .tint(AppTheme.accent)
    }
}

#Preview {
    ContentView()
}
