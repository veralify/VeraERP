import Foundation
import SwiftUI
import Combine

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var supabase = SupabaseClient.shared

    var body: some View {
        NavigationStack {
            Form {
                // Account info
                if let user = viewModel.currentUser {
                    Section("Account") {
                        LabeledContent("Email", value: user.email ?? "–")
                        LabeledContent("Member since") {
                            Text(formattedDate(user.createdAt))
                        }
                    }

                    Section("Display Name") {
                        TextField("Your name", text: $viewModel.displayName)
                        Button {
                            Task { await viewModel.saveProfile() }
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }

                Section("Activity") {
                    NavigationLink(destination: OrderHistoryView()) {
                        Label("Order History", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink(destination: MyESIMsView()) {
                        Label("My eSIMs", systemImage: "simcard.2.fill")
                    }
                }

                Section("Support") {
                    Label("Help Center", systemImage: "questionmark.circle")
                    Label("Contact Us", systemImage: "envelope")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                }
            }
            .navigationTitle("Profile")
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading { ProgressView() }
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

    private func formattedDate(_ iso: String) -> String {
        let df = ISO8601DateFormatter()
        guard let date = df.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

#Preview { ProfileView() }

