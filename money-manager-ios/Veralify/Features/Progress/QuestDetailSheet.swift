import SwiftUI

/// One quest, opened: what it measures, how to finish it, and who ticks it.
///
/// The card in the list has room for a single truncated line, which is enough to
/// recognise a quest and not enough to act on one. "Nothing due in 3 days" in
/// particular reads as a fact rather than a task until you can see what to do
/// about it.
struct QuestDetailSheet: View {
    let quest: Quest
    let isComplete: Bool
    /// Ticking a manual quest from here, so the sheet is not a dead end.
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        howTo
                        whoTicksIt
                        if quest.kind == .manual, !isComplete {
                            PrimaryButton(title: "Mark as done", enabled: true) {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.lime)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: quest.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isComplete ? Theme.green : Theme.lime)
                    .frame(width: 54, height: 54)
                    .background(
                        (isComplete ? Theme.green : Theme.lime).opacity(0.14),
                        in: .rect(cornerRadius: 16)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(quest.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Wraps rather than squeezing: beside the 54pt icon, two
                    // capsules at a large text size overran the line and
                    // broke their labels onto two lines each.
                    FlowRow(spacing: 7) {
                        Pill(
                            text: isComplete
                                ? String(localized: "Done today")
                                : String(localized: "Not yet"),
                            style: .muted(dot: isComplete ? Theme.green : Theme.yellow)
                        )
                        Pill(text: String(localized: "+\(quest.xp) XP"), style: .outlined(Theme.lime))
                    }
                }

                Spacer(minLength: 0)
            }

            Text(quest.detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What to do")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            Text(quest.how)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
    }

    private var whoTicksIt: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: quest.kind == .automatic ? "wand.and.sparkles" : "hand.tap.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(width: 28, height: 28)
                .background(Theme.blue.opacity(0.14), in: .rect(cornerRadius: 9))

            Text(quest.kind == .automatic
                 ? "Veralify ticks this one for you, the moment it is true. There is nothing to confirm."
                 : "Only you can say whether you have done this, so this one is yours to tick.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
