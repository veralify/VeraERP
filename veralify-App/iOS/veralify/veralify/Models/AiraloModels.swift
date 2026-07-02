import Foundation

// MARK: - Response Wrappers

struct AiraloTokenResponse: Decodable {
    let data: TokenData
    struct TokenData: Decodable {
        let tokenType: String
        let expiresIn: Int
        let accessToken: String
        enum CodingKeys: String, CodingKey {
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case accessToken = "access_token"
        }
    }
}

struct AiraloPackagesResponse: Decodable {
    let data: [ESIMPackage]
}

struct AiraloOrderResponse: Decodable {
    let data: AiraloOrder
}

struct AiraloUsageResponse: Decodable {
    let data: SIMUsage
}

// MARK: - Order & SIM

struct AiraloOrder: Codable {
    let id: Int
    let code: String
    let packageID: String
    let quantity: String
    let validity: Int
    let packageName: String
    let data: String
    let price: Double
    let createdAt: String
    let sims: [AiraloSIM]

    enum CodingKeys: String, CodingKey {
        case id, code, quantity, validity, data, price, sims
        case packageID = "package_id"
        case packageName = "package"
        case createdAt = "created_at"
    }
}

struct AiraloSIM: Codable {
    let id: Int
    let iccid: String
    let lpa: String?
    let matchingID: String?
    let qrcode: String?
    let qrcodeURL: String?
    let directAppleInstallationURL: String?
    let apnType: String?
    let isRoaming: Bool

    enum CodingKeys: String, CodingKey {
        case id, iccid, lpa, qrcode
        case matchingID = "matching_id"
        case qrcodeURL = "qrcode_url"
        case directAppleInstallationURL = "direct_apple_installation_url"
        case apnType = "apn_type"
        case isRoaming = "is_roaming"
    }
}

// MARK: - SIM Usage

struct SIMUsage: Codable {
    let remaining: Int?
    let total: Int?
    let status: String?
    let expiredAt: String?

    enum CodingKeys: String, CodingKey {
        case remaining, total, status
        case expiredAt = "expired_at"
    }

    var remainingGB: Double { Double(remaining ?? 0) / 1_073_741_824 }
    var totalGB: Double { Double(total ?? 0) / 1_073_741_824 }

    var usageFraction: Double {
        guard let t = total, t > 0, let r = remaining else { return 0 }
        return 1.0 - (Double(r) / Double(t))
    }

    var formattedRemaining: String {
        let mb = Double(remaining ?? 0) / 1_048_576
        return mb >= 1024 ? String(format: "%.2f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }

    var displayStatus: String { status?.capitalized ?? "Unknown" }

    var isActive: Bool { status == "ACTIVE" }
}
