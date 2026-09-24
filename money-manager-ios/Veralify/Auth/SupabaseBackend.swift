import Foundation
import Supabase
import VeralifyCore

/// `BackendSession` backed by the Supabase Swift client.
///
/// The client keeps the session in the Keychain and refreshes the access
/// token itself, so a user stays signed in across launches, and offline.
final class SupabaseBackend: BackendSession {
    let client: SupabaseClient
    let supabaseURL: URL
    let anonKey: String

    init(configuration: BackendConfiguration) {
        supabaseURL = configuration.url
        anonKey = configuration.anonKey
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: SupabaseClientOptions(
                // Report the stored session at launch as it is, expired or
                // not, instead of first trying to refresh it: offline, the
                // refresh fails, and the user would look signed out of an
                // account whose data is right there on the phone.
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    /// Reads the project URL and anon key the build wrote into Info.plist
    /// (see README → "Backend configuration").
    static func bundleConfiguration(_ bundle: Bundle = .main) throws -> BackendConfiguration {
        try BackendConfiguration.parse(
            url: bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            anonKey: bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        )
    }

    /// The stored session's user. Deliberately not a refreshed session: with
    /// no signal and an expired access token, the user is still signed in.
    var userID: UUID? {
        get async { client.auth.currentSession?.user.id }
    }

    func accessToken() async throws -> String {
        guard client.auth.currentSession != nil else { throw BackendError.signedOut }
        do {
            // Refreshes first when the token is expired or about to be.
            return try await client.auth.session.accessToken
        } catch let error as URLError {
            // Offline is not signed out; callers retry.
            throw error
        } catch {
            throw BackendError.signedOut
        }
    }
}
