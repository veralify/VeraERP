import Foundation

struct VeraUser: Codable, Identifiable {
    let id: String
    let accountIdentifier: String?
    let privyUserId: String?
    let socialProvider: String?
    let socialUserId: String?
    let email: String?
    let phone: String?
    let displayName: String?
    let role: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountIdentifier = "account_identifier"
        case privyUserId = "privy_user_id"
        case socialProvider = "social_provider"
        case socialUserId = "social_user_id"
        case email
        case phone
        case displayName = "display_name"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayNameOrEmail: String {
        displayName ?? email ?? "Unknown User"
    }

    var isAdmin: Bool {
        role == "admin"
    }
}
