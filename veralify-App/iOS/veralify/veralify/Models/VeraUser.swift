import Foundation

struct VeraUser: Codable, Identifiable {
    let id: String
    let email: String?
    let username: String
    let displayName: String?
    let avatarPath: String?
    let bio: String?
    let heightCm: Double?
    let activityLevel: String?
    let timezone: String?
    let onboardingCompleted: Bool
    let isPublic: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email, username, bio, timezone
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case heightCm = "height_cm"
        case activityLevel = "activity_level"
        case onboardingCompleted = "onboarding_completed"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayNameOrEmail: String {
        displayName ?? email ?? username
    }

    var isAdmin: Bool { false }
}
