import SwiftUI

/// Gemini-style chat conversation screen: plain canvas, borderless message
/// flow, and a pill-shaped composer with an attach button and a mic/send
/// control that morphs based on whether the user has typed anything.
/// Reached by pushing from `ChatHomeView`; when `initialPrompt` is supplied
/// (e.g. from a suggestion card), it's sent automatically on appear.
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isComposerFocused: Bool
    @State private var didSendInitialPrompt = false
    var initialPrompt: String?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .background(GlowBackground())
        .navigationTitle("Veralify")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            sendInitialPromptIfNeeded()
        }
        .hidesFloatingNavBar()
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.messages.dropFirst()) { message in
                        ChatBubbleView(message: message)
                            .equatable()
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture { isComposerFocused = false }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages) { oldValue, newValue in
                // Animate only when a brand-new message is appended;
                // token-by-token updates to the same streaming message
                // snap instantly to avoid re-animating the scroll offset
                // dozens of times per second.
                let isNewMessage = oldValue.count != newValue.count
                scrollToBottom(using: proxy, animated: isNewMessage)
            }
        }
    }

    private func sendInitialPromptIfNeeded() {
        guard !didSendInitialPrompt, let prompt = initialPrompt, !prompt.isEmpty else { return }
        didSendInitialPrompt = true
        viewModel.draft = prompt
        viewModel.sendDraft()
    }

    private var composer: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Add attachment")

                TextField(
                    "Ask about training, meals, or progress…",
                    text: $viewModel.draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isComposerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .submitLabel(.send)
                .onSubmit(viewModel.sendDraft)

                sendOrMicButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var sendOrMicButton: some View {
        let hasText = !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        Button(action: viewModel.sendDraft) {
            Image(systemName: hasText ? "arrow.up" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(hasText ? .white : AppTheme.accent)
                .frame(width: 32, height: 32)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .glassEffect(hasText ? .regular.tint(AppTheme.accent).interactive() : .regular.interactive(), in: .circle)
        .disabled(hasText && viewModel.isSending)
        .accessibilityLabel(hasText ? "Send message" : "Voice input")
        .animation(.easeInOut(duration: 0.15), value: hasText)
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
