import Foundation

/// The signed-in connection to Veralify's Supabase project.
///
/// A seam between features: sign-in and sync (Phase 0) provide the session,
/// and anything that talks to the backend — receipt reading, integrations,
/// reports — asks for it here instead of depending on how sign-in works.
/// See docs/RECEIPTS_CONTRACTS.md.
protocol BackendSession: AnyObject, Sendable {
    /// Project URL, e.g. https://xyz.supabase.co
    var supabaseURL: URL { get }
    /// The public anon key, sent as `apikey` on every request.
    var anonKey: String { get }
    /// The signed-in user's id, or nil when signed out.
    var userID: UUID? { get async }
    /// A valid access token (JWT) for the signed-in user, refreshed if it is
    /// about to expire. Throws `BackendError.signedOut` when there is none.
    func accessToken() async throws -> String
}

enum BackendError: Error, Equatable {
    case signedOut
    case notConfigured
}

/// Where features find the session. Set once at launch by the sign-in layer.
@MainActor
enum Backend {
    static var session: BackendSession?

    static func require() throws -> BackendSession {
        guard let session else { throw BackendError.notConfigured }
        return session
    }
}
