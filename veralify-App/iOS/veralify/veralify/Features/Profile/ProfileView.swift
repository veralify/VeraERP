import Foundation
import SwiftUI
import Combine

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var supabase = SupabaseClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileHeader
                    accountCard
                    activityCard
                    settingsCard
                    supportCard
                    signOutCard
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert("Saved!", isPresented: $viewModel.saveSuccess) {
                Button("OK", role: .cancel) {}
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.premiumGradient)

            VStack(alignment: .leading, spacing: 2) {
                if let email = viewModel.currentUser?.email ?? supabase.currentSession?.user.email {
                    Text(email)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("Guest")
                        .font(.headline)
                        .lineLimit(1)
                }
                if let createdAt = viewModel.currentUser?.createdAt {
                    Text("Member since \(formattedDate(createdAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .premiumCard()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Name")
                .font(.headline)
            TextField("Your name", text: $viewModel.displayName)
                .textFieldStyle(.plain)
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))

            Button {
                Task { await viewModel.saveProfile() }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save Changes")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .disabled(viewModel.isSaving)
        }
        .premiumCard()
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)

            NavigationLink(destination: OrderHistoryView()) {
                ProfileRow(icon: "clock.arrow.circlepath", title: "Order History")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: MyESIMsView().hidesFloatingNavBar()) {
                ProfileRow(icon: "simcard.2.fill", title: "My eSIMs")
            }
            .buttonStyle(.plain)
        }
        .premiumCard()
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)

            NavigationLink(destination: LanguageSettingsView()) {
                ProfileRow(icon: "globe", title: "Language")
            }
            .buttonStyle(.plain)
        }
        .premiumCard()
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support")
                .font(.headline)
            ProfileRow(icon: "questionmark.circle", title: "Help Center")
            ProfileRow(icon: "envelope", title: "Contact Us")
        }
        .premiumCard()
    }

    private var signOutCard: some View {
        Button("Sign Out", role: .destructive) {
            Task { await viewModel.signOut() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private func formattedDate(_ iso: String) -> String {
        guard let date = Self.isoFormatter.date(from: iso) else { return iso }
        return Self.displayFormatter.string(from: date)
    }

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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.premiumGradient)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

#Preview { ProfileView() }
