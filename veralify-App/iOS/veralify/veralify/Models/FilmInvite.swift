import Foundation

// MARK: - FilmInvite

struct FilmInvite: Codable, Identifiable, Hashable {
    let id: String
    let filmID: String
    let token: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case filmID = "film_id"
        case token
        case expiresAt = "expires_at"
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }

    /// The universal deep link URL guests tap to join.
    var inviteURL: URL {
        URL(string: "veralify://film/join?token=\(token)")!
    }

    /// HTTPS fallback for guests without the app installed.
    var webFallbackURL: URL {
        URL(string: "https://veralify.com/join?token=\(token)")!
    }
}
