import Foundation

// MARK: - Film

struct Film: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let creatorID: String
    let shotLimit: Int
    let memberLimit: Int
    let revealAt: Date
    let status: FilmStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorID = "creator_id"
        case shotLimit = "shot_limit"
        case memberLimit = "member_limit"
        case revealAt = "reveal_at"
        case status
        case createdAt = "created_at"
    }

    var isRevealed: Bool { status == .revealed }

    var timeUntilReveal: TimeInterval { revealAt.timeIntervalSinceNow }

    var isRevealPast: Bool { revealAt <= Date() }
}

// MARK: - FilmStatus

enum FilmStatus: String, Codable, Hashable {
    case shooting
    case revealed
}

// MARK: - Create Film Request

struct CreateFilmRequest: Encodable {
    let name: String
    let creatorID: String
    let shotLimit: Int
    let memberLimit: Int
    let revealAt: Date

    enum CodingKeys: String, CodingKey {
        case name
        case creatorID = "creator_id"
        case shotLimit = "shot_limit"
        case memberLimit = "member_limit"
        case revealAt = "reveal_at"
    }
}
