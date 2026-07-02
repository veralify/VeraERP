import Foundation
import SwiftUI
import Combine

/// Lightweight Supabase client using URLSession.
/// For production, consider the official Supabase Swift SDK via SPM:
/// https://github.com/supabase/supabase-swift
@MainActor
final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()

    private let baseURL: String
    private let anonKey: String
    private var accessToken: String?

    @Published var isAuthenticated = false
    @Published var currentSession: AuthSession?

    private init() {
        baseURL = AppConfig.supabaseURL
        anonKey = AppConfig.supabaseAnonKey
        restoreSession()
    }

    // MARK: - Session Persistence

    private func restoreSession() {
        if let token = KeychainManager.shared.load(for: .accessToken) {
            accessToken = token
            isAuthenticated = true
        }
    }

    // MARK: - Headers

    private var authHeaders: [String: String] {
        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "application/json"
        ]
        headers["Authorization"] = "Bearer \(accessToken ?? anonKey)"
        return headers
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        let body = ["email": email, "password": password]
        let session: AuthSession = try await post(url: url, body: body)
        saveSession(session)
        return session
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        let body = ["email": email, "password": password]
        let session: AuthSession = try await post(url: url, body: body)
        saveSession(session)
        return session
    }

    func signInWithApple(identityToken: String, nonce: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=id_token")!
        let body: [String: Any] = ["provider": "apple", "id_token": identityToken, "nonce": nonce]
        let session: AuthSession = try await postAny(url: url, body: body)
        saveSession(session)
        return session
    }

    func signInWithGoogle(idToken: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=id_token")!
        let body: [String: Any] = ["provider": "google", "id_token": idToken]
        let session: AuthSession = try await postAny(url: url, body: body)
        saveSession(session)
        return session
    }

    func signOut() async throws {
        let url = URL(string: "\(baseURL)/auth/v1/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        _ = try? await URLSession.shared.data(for: request)
        clearSession()
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token")!
        let body = ["refresh_token": refreshToken]
        let session: AuthSession = try await post(url: url, body: body)
        saveSession(session)
        return session
    }

    func getUser() async throws -> AuthUser {
        let url = URL(string: "\(baseURL)/auth/v1/user")!
        return try await get(url: url)
    }

    // MARK: - Database (PostgREST)

    func select<T: Decodable>(
        from table: String,
        columns: String = "*",
        filters: [String: String] = [:]
    ) async throws -> [T] {
        var components = URLComponents(string: "\(baseURL)/rest/v1/\(table)")!
        var queryItems = [URLQueryItem(name: "select", value: columns)]
        filters.forEach { key, value in
            queryItems.append(URLQueryItem(name: key, value: "eq.\(value)"))
        }
        components.queryItems = queryItems
        return try await get(url: components.url!)
    }

    func insert<T: Codable>(into table: String, data: T) async throws -> T {
        let url = URL(string: "\(baseURL)/rest/v1/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(data)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: responseData)
        let items = try decodeArray(T.self, from: responseData)
        guard let first = items.first else { throw APIError.notFound }
        return first
    }

    /// Update rows. `Input` is the patch payload; `Output` is the full returned row type.
    func update<Input: Encodable, Output: Decodable>(
        table: String,
        data: Input,
        returning: Output.Type = Output.self,
        filters: [String: String]
    ) async throws -> Output {
        var components = URLComponents(string: "\(baseURL)/rest/v1/\(table)")!
        components.queryItems = filters.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(data)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: responseData)
        let items = try decodeArray(Output.self, from: responseData)
        guard let first = items.first else { throw APIError.notFound }
        return first
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

    private func post<T: Decodable, B: Encodable>(url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decode(T.self, from: data)
    }

    private func postAny<T: Decodable>(url: URL, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
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

    private func decodeArray<T: Decodable>(_ type: T.Type, from data: Data) throws -> [T] {
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: http.statusCode, message: message)
        }
    }

    private func saveSession(_ session: AuthSession) {
        currentSession = session
        accessToken = session.accessToken
        KeychainManager.shared.save(session.accessToken, for: .accessToken)
        KeychainManager.shared.save(session.refreshToken, for: .refreshToken)
        isAuthenticated = true
    }

    private func clearSession() {
        currentSession = nil
        accessToken = nil
        KeychainManager.shared.clearAll()
        isAuthenticated = false
    }
}
