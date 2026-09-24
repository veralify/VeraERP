import Foundation

/// The Supabase project the app talks to, read from the build (Info.plist keys
/// `SupabaseURL` and `SupabaseAnonKey`, filled from xcconfig build settings —
/// see the README). Never compiled into source.
public struct BackendConfiguration: Sendable, Equatable {
    public let url: URL
    public let anonKey: String

    public enum Problem: Error, Equatable, CustomStringConvertible {
        case missing(String)
        case invalidURL(String)

        public var description: String {
            switch self {
            case .missing(let key):
                "\(key) is not set. Copy Config/Backend.local.xcconfig.example to Config/Backend.local.xcconfig and fill it in."
            case .invalidURL(let value):
                "SupabaseURL \"\(value)\" is not an https URL. In an xcconfig, write https:/$()/<project>.supabase.co — a bare // starts a comment."
            }
        }
    }

    /// Validates the two raw values as the build left them.
    ///
    /// An unset build setting reaches Info.plist either as an empty string or,
    /// in some Xcode versions, as the literal `$(NAME)`; both are "missing".
    /// Plain http is accepted only for a local Supabase (`supabase start`).
    public static func parse(url rawURL: String?, anonKey rawKey: String?) throws -> BackendConfiguration {
        let urlText = (rawURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (rawKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isUnset(urlText) else { throw Problem.missing("SupabaseURL") }
        guard !isUnset(key) else { throw Problem.missing("SupabaseAnonKey") }

        guard let url = URL(string: urlText), let host = url.host, !host.isEmpty,
              let scheme = url.scheme?.lowercased()
        else { throw Problem.invalidURL(urlText) }
        let isLocal = host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".local")
        guard scheme == "https" || (scheme == "http" && isLocal) else { throw Problem.invalidURL(urlText) }

        return BackendConfiguration(url: url, anonKey: key)
    }

    private static func isUnset(_ value: String) -> Bool {
        value.isEmpty || (value.hasPrefix("$(") && value.hasSuffix(")"))
    }

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}
