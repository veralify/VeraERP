import SwiftUI

enum UserRole: String {
    case admin
    case worker
}

enum AuthProvider {
    case google
    case apple
}

struct UserSession: Equatable {
    let email: String
    let role: UserRole
    let organizationName: String
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var session: UserSession?

    var isLoggedIn: Bool {
        session != nil
    }

    func signIn(with provider: AuthProvider) {
        switch provider {
        case .google:
            session = UserSession(
                email: "admin@veralify.com",
                role: .admin,
                organizationName: "Veralify"
            )
        case .apple:
            session = UserSession(
                email: "worker@veralify.com",
                role: .worker,
                organizationName: "Veralify"
            )
        }
    }

    func signOut() {
        session = nil
    }
}
