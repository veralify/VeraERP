import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Concierge", systemImage: "message.badge.waveform.fill") }

            ExploreView()
                .tabItem { Label("Explore", systemImage: "globe") }

            MyESIMsView()
                .tabItem { Label("My eSIMs", systemImage: "simcard.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(AppTheme.accent)
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
