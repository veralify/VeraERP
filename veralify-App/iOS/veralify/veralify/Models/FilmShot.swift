import Foundation

// MARK: - FilmShot

struct FilmShot: Codable, Identifiable, Hashable {
    let id: String
    let filmID: String
    let memberID: String
    /// Relative path inside the `film-shots` Supabase Storage bucket.
    let storagePath: String
    let capturedAt: Date
    let isRevealed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case filmID = "film_id"
        case memberID = "member_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case isRevealed = "is_revealed"
    }
}

// MARK: - Create Shot Request

struct CreateShotRequest: Encodable {
    let filmID: String
    let memberID: String
    let storagePath: String

    enum CodingKeys: String, CodingKey {
        case filmID = "film_id"
        case memberID = "member_id"
        case storagePath = "storage_path"
    }
}
