import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: ChatRole
    var text: String
    var attachments: [ChatAttachment]
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        attachments: [ChatAttachment] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.attachments = attachments
        self.isStreaming = isStreaming
    }
}

extension ChatMessage {
    static let conciergeGreeting = ChatMessage(
        role: .assistant,
        text: """
        **Welcome to Veralify Coach.**
        Fitness AI chat is not on the active tab surface yet. The generic chat components are preserved for the future coach experience.
        """
    )

    var gatewayMessage: GatewayChatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return GatewayChatMessage(role: role.rawValue, content: trimmed)
    }
}
