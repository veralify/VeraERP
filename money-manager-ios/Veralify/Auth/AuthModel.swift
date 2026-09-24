import Foundation
import Observation
import Supabase
import VeralifyCore

/// Who is signed in, and the ways to change that.
///
/// An account is required (owner decision): every screen past sign-in can
/// assume a user, and all money data syncs to that user's account.
@MainActor
@Observable
final class AuthModel {
    enum State: Equatable {
        /// The build carries no backend configuration. Only a developer sees
        /// this; the message says what to set.
        case unconfigured(String)
        case signedOut
        case signedIn(UUID)
    }

    private(set) var state: State
    /// The signed-in email, when the account has one. An Apple sign-in with a
    /// hidden address has a private relay address here.
    private(set) var email: String?

    @ObservationIgnored let backend: SupabaseBackend?
    @ObservationIgnored private var listener: Task<Void, Never>?

    var userID: UUID? {
        if case .signedIn(let id) = state { return id }
        return nil
    }

    init(backend: SupabaseBackend?, configurationProblem: String?) {
        self.backend = backend
        if let backend {
            // Restored from the Keychain without a network round trip, so the
            // app opens straight into the user's data, online or not. An
            // expired token is refreshed by the client when first needed.
            if let session = backend.client.auth.currentSession {
                state = .signedIn(session.user.id)
                email = session.user.email
            } else {
                state = .signedOut
            }
        } else {
            state = .unconfigured(configurationProblem ?? String(localized: "The app is missing its server settings."))
        }
    }

    /// Follows sign-ins, refreshes and sign-outs from the client, including
    /// a sign-out it decides on itself when a refresh token is revoked.
    func start() {
        guard listener == nil, let backend else { return }
        listener = Task { [weak self] in
            for await (event, session) in backend.client.auth.authStateChanges {
                self?.handle(event, session: session)
            }
        }
    }

    private func handle(_ event: AuthChangeEvent, session: Session?) {
        switch event {
        case .signedOut:
            setSignedOut()
        case .initialSession:
            if let session {
                setSignedIn(session)
            } else if backend?.client.auth.currentSession == nil {
                setSignedOut()
            }
        default:
            if let session { setSignedIn(session) }
        }
    }

    private func setSignedIn(_ session: Session) {
        if state != .signedIn(session.user.id) { state = .signedIn(session.user.id) }
        if email != session.user.email { email = session.user.email }
    }

    private func setSignedOut() {
        if state != .signedOut { state = .signedOut }
        email = nil
    }

    private func client() throws -> SupabaseClient {
        guard let backend else { throw BackendError.notConfigured }
        return backend.client
    }

    // MARK: - Signing in

    /// Completes Sign in with Apple. `nonce` is the raw value whose SHA-256
    /// went into the Apple request; Supabase hashes it again and checks it
    /// against the token, which is what stops a replayed token.
    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client().auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        setSignedIn(session)
    }

    /// Emails a one-time code. Creates the account on first use.
    func sendEmailCode(to email: String) async throws {
        try await client().auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    func verifyEmailCode(email: String, code: String) async throws {
        let response = try await client().auth.verifyOTP(email: email, token: code, type: .email)
        if let session = response.session { setSignedIn(session) }
    }

    // MARK: - Signing out

    /// Ends the session on the server and on this phone. Offline, the server
    /// side cannot be reached, so the phone forgets the session regardless —
    /// a user who asked to sign out must never find themselves still in.
    func signOut() async {
        guard let backend else { return }
        do {
            try await backend.client.auth.signOut()
        } catch {
            try? await backend.client.auth.signOut(scope: .local)
        }
        setSignedOut()
    }

    // MARK: - Deleting the account

    enum DeletionError: LocalizedError {
        case offline
        case refused(String?)

        var errorDescription: String? {
            switch self {
            case .offline:
                String(localized: "You're offline. Connect to the internet and try again.")
            case .refused(let message):
                message ?? String(localized: "Your account could not be deleted. Try again later.")
            }
        }
    }

    /// Deletes the account and everything in it on the server, through the
    /// `account-delete` function (the client cannot delete an auth user). Does
    /// not touch the phone; the caller clears it once this succeeds.
    func deleteAccountOnServer() async throws {
        guard let backend else { throw BackendError.notConfigured }
        let token: String
        do {
            token = try await backend.accessToken()
        } catch is URLError {
            throw DeletionError.offline
        }

        var request = URLRequest(url: backend.supabaseURL.appending(path: "functions/v1/account-delete"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(backend.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"confirm":true}"#.utf8)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is URLError {
            throw DeletionError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw DeletionError.refused(nil) }
        guard (200..<300).contains(http.statusCode) else {
            struct Failure: Decodable { let message: String? }
            throw DeletionError.refused(try? JSONDecoder().decode(Failure.self, from: data).message)
        }
    }

    /// Forgets the session of an account that no longer exists. Local only:
    /// the server has nothing left to sign out of.
    func forgetDeletedAccount() async {
        try? await backend?.client.auth.signOut(scope: .local)
        setSignedOut()
    }
}
