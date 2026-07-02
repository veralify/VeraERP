import Foundation

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String?
    let phone: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case createdAt = "created_at"
    }
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}
