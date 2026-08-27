import Foundation

@MainActor
final class VeralifyAgentManager {
    static let shared = VeralifyAgentManager()

    let coachAgent = VeralifyAgent(
        agentID: .coach,
        displayName: "Veralify Coach",
        mission: "Fitness, nutrition, progress, and community guidance for Veralify.",
        modelName: "backend-configured"
    )

    private let backend = BackendService.shared

    private init() {}

    func streamResponse(
        for userInput: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<VeralifyAgentEvent, Error> {
        let conversation = history.compactMap(\.gatewayMessage)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await delta in await backend.streamChat(
                        prompt: userInput,
                        conversation: conversation,
                        agentID: coachAgent.agentID.rawValue
                    ) {
                        continuation.yield(.textDelta(delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
