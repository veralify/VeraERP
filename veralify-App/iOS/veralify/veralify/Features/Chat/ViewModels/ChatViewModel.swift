import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var messages: [ChatMessage] = [.conciergeGreeting]
    @Published var isSending = false
    @Published var errorMessage: String?

    private let agentManager: VeralifyAgentManager

    init(agentManager: VeralifyAgentManager = .shared) {
        self.agentManager = agentManager
    }

    func sendDraft() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isSending else { return }
        draft = ""

        Task {
            await send(input)
        }
    }

    private func send(_ input: String) async {
        isSending = true
        errorMessage = nil

        messages.append(ChatMessage(role: .user, text: input))
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, text: "", isStreaming: true))

        do {
            let stream = agentManager.streamResponse(for: input, history: messages)
            for try await event in stream {
                apply(event, to: assistantID)
            }
            finalizeAssistantMessage(id: assistantID)
        } catch {
            finalizeAssistantMessage(id: assistantID)
            errorMessage = error.localizedDescription
            appendText("I hit an error: \(error.localizedDescription)", to: assistantID)
        }

        isSending = false
    }

    private func apply(_ event: VeralifyAgentEvent, to assistantID: UUID) {
        switch event {
        case .textDelta(let delta):
            appendText(delta, to: assistantID)
        }
    }

    private func finalizeAssistantMessage(id: UUID) {
        updateMessage(id: id) { message in
            message.isStreaming = false
            message.text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func appendText(_ text: String, to id: UUID) {
        updateMessage(id: id) { message in
            message.text += text
        }
    }


    private func updateMessage(id: UUID, mutate: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[index])
    }
}
