import Foundation
import SwiftUI
import Combine

/// Airalo Partner API client (OAuth2 client_credentials).
/// Docs: https://developers.partners.airalo.com
@MainActor
final class AiraloClient: ObservableObject {
    static let shared = AiraloClient()

    private let baseURL = AppConfig.airaloBaseURL
    private var accessToken: String?
    private var tokenExpiresAt: Date?

    private init() {
        if let token = KeychainManager.shared.load(for: .airaloToken),
           let expiryStr = KeychainManager.shared.load(for: .airaloTokenExpiry),
           let expiry = Double(expiryStr),
           Date().timeIntervalSince1970 < expiry {
            accessToken = token
            tokenExpiresAt = Date(timeIntervalSince1970: expiry)
        }
    }

    // MARK: - Auth

    private func ensureToken() async throws {
        if accessToken != nil, let expiry = tokenExpiresAt, expiry > Date() {
            return
        }
        let url = URL(string: "\(baseURL)/v2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(AppConfig.airaloClientID)&client_secret=\(AppConfig.airaloClientSecret)&grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.unauthorized
        }
        let tokenResp = try JSONDecoder().decode(AiraloTokenResponse.self, from: data)
        accessToken = tokenResp.data.accessToken
        // Subtract 1 hour buffer from expiry
        let expiryDate = Date().addingTimeInterval(TimeInterval(tokenResp.data.expiresIn - 3600))
        tokenExpiresAt = expiryDate
        KeychainManager.shared.save(tokenResp.data.accessToken, for: .airaloToken)
        KeychainManager.shared.save(String(expiryDate.timeIntervalSince1970), for: .airaloTokenExpiry)
    }

    private var authHeaders: [String: String] {
        guard let token = accessToken else { return [:] }
        return ["Authorization": "Bearer \(token)", "Accept": "application/json"]
    }

    // MARK: - Packages

    /// Fetch eSIM plans for a specific country (local) or all regional/global plans.
    func getPackages(countryCode: String? = nil, type: PackageType = .local) async throws -> [ESIMPackage] {
        try await ensureToken()
        var components = URLComponents(string: "\(baseURL)/v2/packages")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "filter[type]", value: type.rawValue),
            URLQueryItem(name: "limit", value: "50")
        ]
        if let code = countryCode {
            items.append(URLQueryItem(name: "filter[country]", value: code))
        }
        components.queryItems = items
        let response: AiraloPackagesResponse = try await get(url: components.url!)
        return response.data
    }

    // MARK: - Orders

    /// Place an order for an eSIM package. The result contains the QR code + install URL.
    func placeOrder(packageID: String) async throws -> AiraloOrder {
        try await ensureToken()
        let url = URL(string: "\(baseURL)/v2/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(fields: [
            "package_id": packageID,
            "quantity": "1",
            "type": "sim",
            "brand_settings_name": AppConfig.eSIMBrandName
        ], boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        let result = try decode(AiraloOrderResponse.self, from: data)
        return result.data
    }

    // MARK: - SIM Usage

    /// Fetch real-time data usage for an installed eSIM.
    func getSimUsage(iccid: String) async throws -> SIMUsage {
        try await ensureToken()
        let url = URL(string: "\(baseURL)/v2/sims/\(iccid)/usage")!
        let response: AiraloUsageResponse = try await get(url: url)
        return response.data
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.decodingError(error) }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:
            throw APIError.httpError(statusCode: http.statusCode,
                                     message: String(data: data, encoding: .utf8))
        }
    }

    private func buildMultipartBody(fields: [String: String], boundary: String) -> Data {
        var body = Data()
        for (name, value) in fields {
            body += "--\(boundary)\r\n".data(using: .utf8)!
            body += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!
            body += "\(value)\r\n".data(using: .utf8)!
        }
        body += "--\(boundary)--\r\n".data(using: .utf8)!
        return body
    }
}

private func += (lhs: inout Data, rhs: Data) { lhs.append(rhs) }
