import SwiftUI
import SwiftData
import VeralifyCore

/// The account button, wearing the level it has earned.
///
/// Level used to be a full-width card in the middle of Today, then briefly a
/// second pill in the navigation bar beside this one. Both were wrong: it is
/// not a figure you read once a day, and it is not a separate thing from the
/// person it belongs to. The ring is the progress towards the next level, the
/// number is the level, and the whole chip opens Account — where the detail is.
struct AccountBadge: View {
    let onOpen: () -> Void

    @Query private var completions: [QuestCompletion]

    private var totalXP: Int { completions.reduce(0) { $0 + $1.xp } }
    private var level: LevelProgress { .forXP(totalXP) }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Theme.stroke, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: level.fraction)
                        .stroke(Theme.lime, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 26, height: 26)
                .animation(.snappy(duration: 0.4), value: level.fraction)

                Text("\(level.level)")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.4), value: level.level)
                    // On the label alone, not the chip: the toolbar offers its
                    // item a width and the number was being squeezed out of
                    // existence. Sizing the whole chip past that offer instead
                    // drew it fine but left the tap target behind, at the size
                    // the toolbar had decided on.
                    .fixedSize()
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 34)
            .background(Theme.surfaceElevated, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Account, level \(level.level)")
    }
}

/// Level, XP and what earns it. Lives at the top of the Account sheet, which is
/// where everything about the person sits.
struct LevelPanel: View {
    @Query private var completions: [QuestCompletion]

    private var totalXP: Int { completions.reduce(0) { $0 + $1.xp } }
    private var level: LevelProgress { .forXP(totalXP) }

    /// The same marks the inline card carried.
    private var milestones: [Int] { [50, 150, 300, 600] }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Your level") { EmptyView() }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Level \(level.level)", systemImage: "crown.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    Text("\(level.intoLevel)/\(level.levelSpan) XP")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.lime)
                }

                MilestoneTrack(
                    fraction: level.fraction,
                    milestones: milestones,
                    floor: level.levelFloor,
                    ceiling: level.nextLevelAt
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

            GroupedCard {
                row("Earned so far", "\(totalXP) XP")
                RowDivider()
                row("Next level at", "\(level.nextLevelAt) XP")
                RowDivider()
                row("Still to go", "\(max(level.nextLevelAt - totalXP, 0)) XP")
            }

            Text("XP comes from finishing the day's quests on Today. Nothing else earns it, and nothing takes it away.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 13)
    }
}
