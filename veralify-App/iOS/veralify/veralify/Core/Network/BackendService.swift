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

    private func streamMockResponse(
        prompt: String,
        agentID: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let lowerPrompt = prompt.lowercased()
        let mockText: String

        if agentID == VeralifyAgentID.flightOTA.rawValue || lowerPrompt.contains("flight") {
            mockText = "I can help compare premium fares and highlight the best-value itinerary for your trip."
        } else if agentID == VeralifyAgentID.esim.rawValue || lowerPrompt.contains("esim") {
            mockText = "I found flexible eSIM data packages with instant activation and strong roaming coverage."
        } else {
            mockText = "Welcome to Veralify Concierge. Ask me for flights, eSIM plans, or local travel tips."
        }

        for token in mockText.split(separator: " ", omittingEmptySubsequences: true) {
            continuation.yield(String(token) + " ")
            try await Task.sleep(for: .milliseconds(55))
        }
    }
}
