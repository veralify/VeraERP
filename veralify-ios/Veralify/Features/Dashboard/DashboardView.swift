import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCardView(title: "Documents", value: "0", icon: "doc.fill", tint: .blue)
                        StatCardView(title: "Projects", value: "5", icon: "folder.fill", tint: .orange)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Documents")
                            .font(.headline)

                        if authManager.session?.role == .admin {
                            DocumentRowView(title: "Upload document", icon: "plus.circle.fill", tint: .blue)
                        } else {
                            Text("No documents assigned yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
            }
            .navigationTitle("Dashboard")
            .safeAreaInset(edge: .top) {
                if let email = authManager.session?.email {
                    Text("Welcome, \(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
