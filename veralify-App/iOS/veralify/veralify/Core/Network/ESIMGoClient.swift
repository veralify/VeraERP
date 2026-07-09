import Foundation
import SwiftUI
import Combine

/// eSIM Go API client.
/// Docs: https://docs.esim-go.com
@MainActor
final class ESIMGoClient: ObservableObject {
    static let shared = ESIMGoClient()

    private let baseURL = AppConfig.esimGoBaseURL

    private init() {}

    private var authHeaders: [String: String] {
        [
            "X-API-Key": AppConfig.esimGoAPIKey,
            "Accept": "application/json"
        ]
    }

    // MARK: - Packages

    /// Fetch eSIM plans for a specific country (local) or multi-country catalogue (regional/global).
    func getPackages(countryCode: String? = nil, type: PackageType = .local) async throws -> [ESIMPackage] {
        var components = URLComponents(string: "\(baseURL)/catalogue")!
        var queryItems: [URLQueryItem] = [
            .init(name: "page", value: "1"),
            .init(name: "perPage", value: "200")
        ]
        if let countryCode {
            queryItems.append(.init(name: "countries", value: countryCode.uppercased()))
        }
        components.queryItems = queryItems

        let bundles: [ESIMGoCatalogueBundle] = try await get(url: components.url!)
        let packages = bundles.map(ESIMPackage.init(bundle:))

        switch type {
        case .local:
            return countryCode == nil ? packages.filter { $0.planCategory == .local } : packages
        case .global:
            return packages.filter { $0.planCategory != .local }
        }
    }

    // MARK: - Orders

    /// Places an order and returns assigned eSIM install details.
    func placeOrder(packageID: String) async throws -> ESIMGoOrderResult {
        let url = URL(string: "\(baseURL)/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ESIMGoCreateOrderRequest(
            type: "transaction",
            assign: true,
            profileID: AppConfig.esimGoBrandingProfileID.isEmpty ? nil : AppConfig.esimGoBrandingProfileID,
            order: [
                .init(
                    type: "bundle",
                    quantity: 1,
                    item: packageID,
                    iccids: nil,
                    allowReassign: true
                )
            ]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        let orderResponse = try decode(ESIMGoOrderResponse.self, from: data)
        guard let item = orderResponse.order.first else { throw APIError.notFound }

        let installedESIM = try await getInstallDetails(reference: orderResponse.orderReference)
        return ESIMGoOrderResult(
            orderReference: orderResponse.orderReference,
            item: item.item,
            quantity: item.quantity,
            total: orderResponse.total,
            createdDate: orderResponse.createdDate,
            esims: [installedESIM]
        )
    }

    // MARK: - Usage

    /// Fetches latest bundle assignment usage for an eSIM.
    func getSimUsage(iccid: String) async throws -> SIMUsage {
        var components = URLComponents(string: "\(baseURL)/esims/\(iccid)/bundles")!
        components.queryItems = [
            .init(name: "includeUsed", value: "true"),
            .init(name: "limit", value: "50")
        ]
        let response: ESIMGoESIMBundlesResponse = try await get(url: components.url!)
        let latestAssignment = response.bundles
            .flatMap(\.assignments)
            .sorted(by: { $0.assignmentDateTime > $1.assignmentDateTime })
            .first

        guard let latestAssignment else {
            return SIMUsage(remaining: nil, total: nil, status: nil, expiredAt: nil)
        }

        return SIMUsage(
            remaining: latestAssignment.remainingQuantity,
            total: latestAssignment.initialQuantity,
            status: latestAssignment.bundleState.uppercased(),
            expiredAt: latestAssignment.endDateTime
        )
    }

    // MARK: - Private

    private func getInstallDetails(reference: String) async throws -> ESIMGoInstalledESIM {
        var components = URLComponents(string: "\(baseURL)/esims/assignments")!
        components.queryItems = [
            .init(name: "reference", value: reference),
            .init(name: "additionalFields", value: "appleInstallUrl")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let first: ESIMGoInstalledESIM?
        if let list = try? decode([ESIMGoInstalledESIM].self, from: data) {
            first = list.first
        } else {
            first = try? decode(ESIMGoInstalledESIM.self, from: data)
        }
        guard let first else { throw APIError.notFound }
        return first
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
    }
}
