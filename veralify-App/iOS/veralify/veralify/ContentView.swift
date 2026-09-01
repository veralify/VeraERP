import SwiftUI

struct ContentView: View {
    @ObservedObject private var supabase = SupabaseClient.shared
    @StateObject private var onboardingStatus = OnboardingStatusStore()
    @State private var entitlementStore = EntitlementStore.shared
    @State private var storeKitManager = StoreKitManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if supabase.isAuthenticated {
                authenticatedContent
            } else {
                LoginView()
            }
        }
        .tint(VeraTokens.Colors.primary)
        .task { await bootstrapAuthenticatedState() }
        .onChange(of: supabase.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task { await bootstrapAuthenticatedState() }
            } else {
                onboardingStatus.markNeedsOnboarding()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, supabase.isAuthenticated else { return }
            Task {
                await entitlementStore.refresh()
                await onboardingStatus.refresh()
            }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        switch onboardingStatus.status {
        case .loading:
            ProgressView("Loading profile…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.screenBackground.ignoresSafeArea())
        case .needsOnboarding:
            OnboardingFlowView {
                Task { await onboardingStatus.refresh() }
            }
            .environment(entitlementStore)
            .environment(storeKitManager)
        case .complete:
            AppShellView()
                .environment(entitlementStore)
                .environment(storeKitManager)
        case .failed(let message):
            VStack(spacing: VeraTokens.Spacing._4) {
                Text("Could not load profile")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await onboardingStatus.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(VeraTokens.Spacing._5)
            .background(AppTheme.screenBackground.ignoresSafeArea())
        }
    }

    private func bootstrapAuthenticatedState() async {
        guard supabase.isAuthenticated else { return }
        await onboardingStatus.refresh()
        await entitlementStore.refreshIfNeeded()
        await storeKitManager.loadProducts()
        await storeKitManager.restoreCurrentEntitlements()
    }
}

#Preview { ContentView() }
