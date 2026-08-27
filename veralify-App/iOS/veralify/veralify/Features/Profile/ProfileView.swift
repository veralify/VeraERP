import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(EntitlementStore.self) private var entitlementStore
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VeraTokens.Spacing._4) {
                    profileHeader
                    accountCard
                    subscriptionCard
                    filmCard
                    settingsCard
                    appCard
                    signOutCard
                }
                .padding(VeraTokens.Spacing._4)
                .safeAreaPadding(.bottom, VeraTokens.SafeArea.bottomNavClearance)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert("Saved", isPresented: $viewModel.saveSuccess) { Button("OK", role: .cancel) {} }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: VeraTokens.Spacing._3) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.premiumGradient)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VeraTokens.Colors.fg)
                    .lineLimit(1)
                if let email = viewModel.currentUser?.email ?? viewModel.authUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                        .lineLimit(1)
                }
                if let createdAt = viewModel.currentUser?.createdAt ?? viewModel.authUser?.createdAt {
                    Text("Member since \(formattedDate(createdAt))")
                        .font(.caption)
                        .foregroundStyle(VeraTokens.Colors.fgSubtle)
                }
            }
            Spacer()
        }
        .premiumCard()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Text("Handle / display name")
                .font(.headline)
            TextField("Your name", text: $viewModel.displayName)
                .textFieldStyle(.plain)
                .padding(VeraTokens.Spacing._3)
                .background(RoundedRectangle(cornerRadius: VeraTokens.Radii.md).fill(VeraTokens.Colors.surface))

            Button {
                Task { await viewModel.saveProfile() }
            } label: {
                if viewModel.isSaving { ProgressView() } else { Text("Save Profile") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSaving || viewModel.currentUser == nil)
        }
        .premiumCard()
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Text("Subscription")
                .font(.headline)
            Text(entitlementStore.activeKeys.isEmpty ? "No active backend entitlements" : "Active entitlements: \(entitlementStore.activeKeys.count)")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
            Button("Manage subscription") { isShowingPaywall = true }
                .buttonStyle(.borderedProminent)
        }
        .premiumCard()
    }

    private var filmCard: some View {
        NavigationLink(destination: FilmsHomeView().hidesFloatingNavBar()) {
            ProfileRow(icon: "camera.aperture", title: "Shared Film")
        }
        .buttonStyle(.plain)
        .premiumCard()
    }

    private var settingsCard: some View {
        NavigationLink(destination: LanguageSettingsView()) {
            ProfileRow(icon: "globe", title: "Language")
        }
        .buttonStyle(.plain)
        .premiumCard()
    }

    private var appCard: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            Text(AppConfig.appName)
                .font(.headline)
            Text(AppConfig.appTagline)
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
            Text("Version \(Self.version) (\(Self.build))")
                .font(.caption)
                .foregroundStyle(VeraTokens.Colors.fgSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private var signOutCard: some View {
        Button("Sign Out", role: .destructive) {
            Task { await viewModel.signOut() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private var displayName: String {
        viewModel.currentUser?.displayName ?? viewModel.currentUser?.email ?? viewModel.authUser?.email ?? "Veralify member"
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = Self.isoFormatter.date(from: iso) else { return iso }
        return Self.displayFormatter.string(from: date)
    }

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    private static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    private static let isoFormatter = ISO8601DateFormatter()
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

private struct ProfileRow: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: VeraTokens.Spacing._3) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.premiumGradient)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VeraTokens.Colors.fg)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VeraTokens.Colors.fgSubtle)
        }
        .padding(.vertical, VeraTokens.Spacing._2)
    }
}

#Preview {
    ProfileView()
        .environment(EntitlementStore.shared)
        .environment(StoreKitManager.shared)
}
