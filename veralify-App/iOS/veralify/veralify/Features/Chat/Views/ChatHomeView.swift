import SwiftUI

/// Discovery-style home screen: greeting, quick-action pills, a grid of
/// suggestion cards, and a recent-prompts list — each entry pushes into a
/// full chat conversation. Kept intentionally lightweight (no message list,
/// no streaming state) so opening the app is instant; the heavier
/// `ChatView` only loads once the user actually starts a conversation.
struct ChatHomeView: View {
    @Binding var path: [String]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    quickActions
                    suggestionGrid
                    recentPrompts
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .background(GlowBackground())
            .navigationDestination(for: String.self) { prompt in
                ChatView(initialPrompt: prompt)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("VeralifyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            Text("Hey there!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.sparkleGradient)

            Text("What are you building today?")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                QuickActionPill(icon: "message.fill", tint: AppTheme.ink, title: "Ask Coach") {
                    path.append("")
                }
                QuickActionPill(icon: "mic.fill", tint: AppTheme.accent, title: "Voice Note") {
                    path.append("")
                }
            }
        }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for you")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.suggestionCards) { card in
                    Button {
                        path.append(card.prompt)
                    } label: {
                        SuggestionCardView(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentPrompts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent prompts")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(Self.recentPromptExamples, id: \.self) { prompt in
                    Button {
                        path.append(prompt)
                    } label: {
                        RecentPromptRow(text: prompt)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static let suggestionCards: [SuggestionCard] = [
        SuggestionCard(icon: "figure.strengthtraining.traditional", tint: AppTheme.ink, title: "Plan a Workout", subtitle: "Training guidance lands later", prompt: "Plan a strength workout"),
        SuggestionCard(icon: "fork.knife", tint: AppTheme.accent, title: "Improve Nutrition", subtitle: "Food and macro coaching lands later", prompt: "Help me hit my protein goal")
    ]

    private static let recentPromptExamples = [
        "How should I start tracking meals?",
        "What progress photos should I take?",
        "How can I build consistency this week?"
    ]
}

private struct SuggestionCard: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let prompt: String
}

private struct QuickActionPill: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.gradient))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct SuggestionCardView: View {
    let card: SuggestionCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: card.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(card.tint.gradient))

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(card.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.composerFill)
        )
    }
}

private struct RecentPromptRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppTheme.accent.gradient))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.composerFill)
        )
    }
}

#Preview {
    ChatHomeView(path: .constant([]))
}
