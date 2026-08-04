import Foundation

// MARK: - FilmMember

struct FilmMember: Codable, Identifiable, Hashable {
    let id: String
    let filmID: String
    /// Nil for guest participants — they are identified by their guestToken instead.
    let userID: String?
    let guestToken: String?
    let displayName: String
    let shotsUsed: Int
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case filmID = "film_id"
        case userID = "user_id"
        case guestToken = "guest_token"
        case displayName = "display_name"
        case shotsUsed = "shots_used"
        case joinedAt = "joined_at"
    }

    var isGuest: Bool { userID == nil }
}

// MARK: - Join Film Request

struct JoinFilmRequest: Encodable {
    let filmID: String
    let userID: String?
    let guestToken: String?
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case filmID = "film_id"
        case userID = "user_id"
        case guestToken = "guest_token"
        case displayName = "display_name"
    }
}
