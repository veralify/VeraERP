import SwiftUI

struct ContentView: View {
    @ObservedObject private var supabase = SupabaseClient.shared
    @State private var entitlementStore = EntitlementStore.shared
    @State private var storeKitManager = StoreKitManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if supabase.isAuthenticated {
                AppShellView()
                    .environment(entitlementStore)
                    .environment(storeKitManager)
            } else {
                LoginView()
            }
        }
        .tint(VeraTokens.Colors.primary)
        .task {
            guard supabase.isAuthenticated else { return }
            await entitlementStore.refreshIfNeeded()
            await storeKitManager.loadProducts()
            await storeKitManager.restoreCurrentEntitlements()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, supabase.isAuthenticated else { return }
            Task { await entitlementStore.refresh() }
        }
    }
}

#Preview { ContentView() }
