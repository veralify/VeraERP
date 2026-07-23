import SwiftUI

/// Gemini-style message row: assistant replies render as plain, borderless
/// text flowing full-width (no card), while the user's own messages appear
/// as a light rounded pill aligned to the trailing edge.
///
/// Conforms to `Equatable` so `.equatable()` can be applied where this view
/// is used in a list — SwiftUI then skips re-invoking `body` (and re-parsing
/// markdown) for every historical row each time a *different* row's
/// streaming text updates, instead of re-rendering the whole message list
/// on every token.
struct ChatBubbleView: View, Equatable {
    let message: ChatMessage

    static func == (lhs: ChatBubbleView, rhs: ChatBubbleView) -> Bool {
        lhs.message == rhs.message
    }

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 42) }

            VStack(alignment: .leading, spacing: 10) {
                if !message.text.isEmpty {
                    // While tokens are still streaming in, render plain text —
                    // re-running the markdown parser on the whole growing
                    // string for every delta is O(n²) and causes visible jank.
                    // Markdown formatting is applied once streaming finishes.
                    if message.isStreaming {
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    } else {
                        Text(markdownText(from: message.text))
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }

                ForEach(message.attachments) { attachment in
                    attachmentView(for: attachment)
                }

                if message.isStreaming {
                    HStack(spacing: 6) {
                        Image("VeralifyLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .padding(isUser ? 14 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isUser {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppTheme.userBubble)
                    }
                }
            )

            if !isUser { Spacer(minLength: 24) }
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
