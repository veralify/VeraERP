import Foundation

actor BackendService {
    static let shared = BackendService()

    private let baseURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL? = URL(string: AppConfig.backendGatewayBaseURL)) {
        self.baseURL = baseURL ?? URL(string: "https://api.veralify.com/v1")!
    }

    /// Streams response deltas from Veralify's backend gateway.
    /// The gateway is responsible for LLM orchestration and partner API credentials.
    func streamChat(
        prompt: String,
        conversation: [GatewayChatMessage],
        agentID: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    if AppConfig.useMockGatewayResponses {
                        try await streamMockResponse(prompt: prompt, agentID: agentID, continuation: continuation)
                        continuation.finish()
                        return
                    }

                    var request = URLRequest(url: baseURL.appending(path: "chat/stream"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try encoder.encode(
                        GatewayChatRequest(
                            agentID: agentID,
                            model: "gpt-4o-mini",
                            messages: conversation,
                            prompt: prompt
                        )
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.unknown
                    }
                    guard 200...299 ~= http.statusCode else {
                        throw APIError.httpError(statusCode: http.statusCode, message: nil)
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }

                        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if payload.isEmpty { continue }

                        if
                            let data = payload.data(using: .utf8),
                            let chunk = try? decoder.decode(GatewayStreamChunk.self, from: data),
                            let delta = chunk.delta ?? chunk.content,
                            !delta.isEmpty
                        {
                            continuation.yield(delta)
                        } else {
                            continuation.yield(payload)
                        }
                    }

                    continuation.finish()
                } catch {
                    if let apiError = error as? APIError {
                        continuation.finish(throwing: apiError)
                    } else {
                        continuation.finish(throwing: APIError.networkError(error))
                    }
                }
            }
        }
    }

    func validateIAPTransaction(_ payload: IAPValidationPayload) async throws {
        var request = URLRequest(url: baseURL.appending(path: "iap/validate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: responseData)
    }

    private func streamMockResponse(
        prompt: String,
        agentID: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        _ = agentID
        let lowerPrompt = prompt.lowercased()
        let mockText: String

        if lowerPrompt.contains("food") || lowerPrompt.contains("meal") {
            mockText = "Food logging arrives in a later phase. For now, your nutrition data will appear in Track after implementation."
        } else if lowerPrompt.contains("coach") || lowerPrompt.contains("progress") {
            mockText = "Veralify Coach and progress insights are planned for later phases. Entitlements are already wired to the backend source of truth."
        } else {
            mockText = "Welcome to Veralify. Track, connect, and transform with fitness insights as upcoming phases come online."
        }

        for token in mockText.split(separator: " ", omittingEmptySubsequences: true) {
            continuation.yield(String(token) + " ")
            try await Task.sleep(for: .milliseconds(55))
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(statusCode: http.statusCode, message: String(data: data, encoding: .utf8))
        }
    }
}
