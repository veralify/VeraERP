import SwiftUI
import SwiftData
import MoneyManagerCore

/// Streak, level and today's quests.
struct ProgressSection: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var completions: [QuestCompletion]

    /// Passed in so quest evaluation uses exactly the figures the dashboard
    /// shows, rather than recomputing and risking a disagreement.
    let netCashFlow: Decimal
    let soonestDueInDays: Int?

    /// Fires the burst when a quest is ticked.
    @State private var burstTrigger = false
    @State private var burstQuestID: String?
    /// Quests held on screen for a beat after completing, so the tick and the
    /// burst are actually seen before the row dissolves away.
    @State private var lingering: Set<String> = []
    /// False until the entrance roll has run, so figures start at zero.
    @State private var isRolling = false

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }

    /// A day counts as active if anything was logged or any quest ticked.
    private var activeDays: [Date] {
        transactions.map(\.occurredAt) + completions.map(\.day)
    }

    private var streak: Int {
        StreakCalculator.current(activeDays: activeDays, now: .now, calendar: calendar)
    }

    private var week: [(day: Date, isActive: Bool)] {
        StreakCalculator.week(activeDays: activeDays, now: .now, calendar: calendar)
    }

    private var totalXP: Int {
        let manual = completions.reduce(0) { $0 + $1.xp }
        // Automatic quests pay out for today only; historical days would need a
        // snapshot of that day's finances, which is not recorded.
        let automatic = Quest.all
            .filter { $0.kind == .automatic && isSatisfied($0) }
            .reduce(0) { $0 + $1.xp }
        return manual + automatic
    }

    private var level: LevelProgress { .forXP(totalXP) }

    /// Checkpoints inside the current level, one per quest's worth of XP.
    private var milestones: [Int] {
        let step = Quest.all.first?.xp ?? 25
        return stride(from: level.levelFloor + step, through: level.nextLevelAt, by: step).map { $0 }
    }

    /// What is still to do — plus any row being held for its exit animation.
    private var outstanding: [Quest] {
        Quest.all.filter { !isComplete($0) || lingering.contains($0.id) }
    }

    private var allDoneCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.lime)
            VStack(alignment: .leading, spacing: 2) {
                Text("All done for today")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Quests reset at midnight.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .accessibilityElement(children: .combine)
    }

    private var completedToday: Int {
        Quest.all.filter { isComplete($0) }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            streakCard.staggeredAppearance(0)
            levelCard.staggeredAppearance(1)
            questList.staggeredAppearance(2)
        }
        .animation(.smooth(duration: 0.45), value: outstanding.map(\.id))
        .countUpOnAppear($isRolling)
    }

    // MARK: - Cards

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STREAK")
                        .font(.caption.weight(.bold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    RollingNumber(value: isRolling ? Double(streak) : 0) { value in
                        Text("\(Int(value.rounded())) days")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 26))
                    .foregroundStyle(streak > 0 ? Theme.yellow : Theme.textTertiary)
            }

            HStack(spacing: 6) {
                ForEach(week, id: \.day) { entry in
                    VStack(spacing: 5) {
                        Text(entry.day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                        Image(systemName: entry.isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(entry.isActive ? Theme.green : Theme.stroke)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Level \(level.level)", systemImage: "crown.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.4), value: level.level)
                Spacer(minLength: 8)
                RollingNumber(value: isRolling ? Double(level.intoLevel) : 0) { value in
                    Text("\(Int(value.rounded()))/\(level.levelSpan) XP")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.lime)
                }
            }

            MilestoneTrack(
                fraction: isRolling ? level.fraction : 0,
                milestones: milestones,
                floor: level.levelFloor,
                ceiling: level.nextLevelAt
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var questList: some View {
        VStack(spacing: 10) {
            questHeader

            if outstanding.isEmpty {
                allDoneCard
            } else {
                // Separate cards rather than one grouped block with dividers:
                // each quest is its own object to act on, and the gaps let a
                // completed one dissolve without the rest visibly reflowing.
                ForEach(outstanding) { quest in
                    questCard(quest)
                        .transition(.dissolve)
                }
            }
        }
    }

    private var questHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's quests")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Quests reset at midnight")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                CompletionRing(completed: isRolling ? completedToday : 0, total: Quest.all.count)
                RollingNumber(value: isRolling ? Double(completedToday) : 0) { value in
                    Text("\(Int(value.rounded()))/\(Quest.all.count) completed")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func questCard(_ quest: Quest) -> some View {
        let done = isComplete(quest)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: quest.icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(done ? Theme.green : Theme.textSecondary)
                .frame(width: 40, height: 40)
                .background(
                    done ? Theme.green.opacity(0.14) : Theme.surfaceElevated,
                    in: .rect(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(done, color: Theme.textTertiary)
                    .lineLimit(1)

                Text(quest.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                rewardChip(quest)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            Group {
                if quest.kind == .manual {
                    Button { toggle(quest) } label: {
                        checkmark(done: done)
                            .overlay {
                                if burstQuestID == quest.id {
                                    ParticleBurst(trigger: burstTrigger)
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(done ? "Mark as not done" : "Mark as done")
                } else {
                    // Automatic quests are status, not a control.
                    checkmark(done: done)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .animation(.snappy(duration: 0.25), value: done)
        .sensoryFeedback(.success, trigger: done) { _, isDone in isDone }
        .accessibilityElement(children: .combine)
    }

    private func rewardChip(_ quest: Quest) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
            Text("+\(quest.xp) XP")
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.lime)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Theme.lime.opacity(0.12), in: .capsule)
    }

    private func checkmark(done: Bool) -> some View {
        ZStack {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.green)
            } else {
                // Dashed rather than solid: an outstanding quest reads as a
                // slot waiting to be filled, not as a control already drawn.
                Circle()
                    .strokeBorder(
                        Theme.textTertiary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3.5, 3.5])
                    )
                    .frame(width: 26, height: 26)
            }
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Evaluation

    private func isComplete(_ quest: Quest) -> Bool {
        switch quest.kind {
        case .automatic: isSatisfied(quest)
        case .manual:    completions.contains { $0.questID == quest.id && calendar.isDate($0.day, inSameDayAs: today) }
        }
    }

    private func isSatisfied(_ quest: Quest) -> Bool {
        switch quest.id {
        case "log-entry":
            transactions.contains { calendar.isDate($0.occurredAt, inSameDayAs: today) }
        case "in-surplus":
            netCashFlow >= 0
        case "nothing-overdue":
            (soonestDueInDays ?? .max) > 3
        default:
            false
        }
    }

    private func toggle(_ quest: Quest) {
        guard !isComplete(quest) else { return }

        context.insert(QuestCompletion(questID: quest.id, day: today, xp: quest.xp))
        try? context.save()

        // Keep the row up while the tick and burst play, then dissolve it.
        lingering.insert(quest.id)
        burstQuestID = quest.id
        burstTrigger.toggle()

        Task {
            try? await Task.sleep(for: .milliseconds(620))
            withAnimation(.smooth(duration: 0.45)) {
                _ = lingering.remove(quest.id)
            }
        }
    }
}
