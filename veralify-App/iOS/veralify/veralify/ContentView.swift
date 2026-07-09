import SwiftUI

struct ContentView: View {
    @ObservedObject private var supabase = SupabaseClient.shared

    var body: some View {
        Group {
            if supabase.isAuthenticated {
                TabView {
                    ExploreView()
                        .tabItem { Label("Explore", systemImage: "globe") }

                    MyESIMsView()
                        .tabItem { Label("My eSIMs", systemImage: "simcard.2.fill") }

                    ProfileView()
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                }
                .tint(AppTheme.accent)
            } else {
                LoginView()
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
