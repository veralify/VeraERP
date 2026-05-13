import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 32)

            VStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Veralify")
                    .font(.largeTitle.bold())

                Text("Organization document management")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    authManager.signIn(with: .google)
                } label: {
                    Label("Sign in with Google", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    authManager.signIn(with: .apple)
                } label: {
                    Label("Sign in with Apple", systemImage: "applelogo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.primary)
            }
        }
        .padding(24)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
