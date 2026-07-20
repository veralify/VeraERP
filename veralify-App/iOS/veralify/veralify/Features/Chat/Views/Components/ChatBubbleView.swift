import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 42) }

            VStack(alignment: .leading, spacing: 10) {
                if !message.text.isEmpty {
                    Text(markdownText(from: message.text))
                        .font(.body)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }

                ForEach(message.attachments) { attachment in
                    attachmentView(for: attachment)
                }

                if message.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.8))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUser ? Color.indigo.opacity(0.45) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 42) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private func attachmentView(for attachment: ChatAttachment) -> some View {
        switch attachment.kind {
        case .flight(let flight):
            FlightCardView(flight: flight)
        case .esim(let esim):
            eSIMCardView(plan: esim)
        }
    }

    private func markdownText(from source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}
