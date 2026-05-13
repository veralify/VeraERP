import SwiftUI

struct MainTabView: View {
    private enum Tab {
        case dashboard
        case profile
    }

    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(Tab.dashboard)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
