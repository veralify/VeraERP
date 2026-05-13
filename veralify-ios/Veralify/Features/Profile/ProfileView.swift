import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showSignOutDialog = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 10) {
                    ProfileFieldView(label: "Email", value: authManager.session?.email ?? "-")
                    ProfileFieldView(label: "Role", value: (authManager.session?.role.rawValue ?? "-").uppercased())
                    ProfileFieldView(label: "Organization", value: authManager.session?.organizationName ?? "-")
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button(role: .destructive) {
                    showSignOutDialog = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .navigationTitle("Profile")
            .confirmationDialog("Sign out?", isPresented: $showSignOutDialog, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
