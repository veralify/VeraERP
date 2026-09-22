import SwiftUI
import SwiftData
import VeralifyCore

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
    /// Per-task completion counter. The effect views stay mounted and watch
    /// their own row's count, because `keyframeAnimator` ignores a trigger that
    /// arrives with the view rather than after it.
    @State private var celebrationIDs: [String: Int] = [:]
    /// The task currently being celebrated, for the card's highlight.
    @State private var celebratingQuestID: String?
    @State private var rewardLabels: [String: String] = [:]
    /// Guards against a second tap landing while a completion is in flight.
    @State private var inFlight: Set<String> = []
    @State private var levelUpTo: Int?
    @State private var levelUpID = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Quests held on screen for a beat after completing, so the tick and the
    /// burst are actually seen before the row dissolves away.
    @State private var lingering: Set<String> = []
    /// False until the entrance roll has run, so figures start at zero.
    @State private var isRolling = false
    /// The quest whose instructions are open.
    @State private var opened: Quest?

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
            questList.staggeredAppearance(1)
        }
        .sheet(item: $opened) { quest in
            QuestDetailSheet(quest: quest, isComplete: isComplete(quest)) {
                completeTask(quest.id, reward: quest.xp)
            }
            .presentationBackground(Theme.background)
        }
        .animation(.smooth(duration: 0.45), value: outstanding.map(\.id))
        .countUpOnAppear($isRolling)
        .overlay(alignment: .top) {
            if let levelUpTo {
                LevelUpBanner(level: levelUpTo, trigger: levelUpID)
                    .offset(y: -6)
            }
        }
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
        let celebrating = celebratingQuestID == quest.id

        return HStack(alignment: .top, spacing: 12) {
            // The left of the card opens the instructions; the tick on the
            // right stays its own control. Nesting the two would mean the outer
            // button swallowed every tap meant for the inner one.
            Button { opened = quest } label: {
                questSummary(quest, done: done)
            }
            .buttonStyle(.pressable)

            Spacer(minLength: 8)

            CompletionButton(
                isComplete: done,
                celebrationID: celebrationIDs[quest.id, default: 0],
                isInteractive: quest.kind == .manual
            ) {
                completeTask(quest.id, reward: quest.xp)
            }
            // Mounted from the start, invisible until its count changes.
            .overlay(alignment: .top) {
                FloatingReward(
                    text: rewardLabels[quest.id] ?? "+\(quest.xp) XP",
                    trigger: celebrationIDs[quest.id, default: 0]
                )
                .offset(y: -6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        // A brief highlight, then it settles back.
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.green.opacity(celebrating ? 0.55 : 0), lineWidth: 1.5)
        )
        .shadow(color: Theme.green.opacity(celebrating ? 0.28 : 0), radius: 18, y: 6)
        .scaleEffect(celebrating && !reduceMotion ? 1.015 : 1)
        .animation(.bouncy(duration: 0.45), value: celebrating)
        .sensoryFeedback(.success, trigger: celebrationIDs[quest.id, default: 0])
    }

    private func questSummary(_ quest: Quest, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
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
                    // Dimmed but still readable, not greyed into illegibility.
                    .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(done, color: Theme.textTertiary)
                    .lineLimit(1)

                Text(quest.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 7) {
                    rewardChip(quest)
                    // Says the card has more behind it than the truncated line.
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 2)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows what to do")
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

    /// Completes a task and pays out its reward.
    ///
    /// The single entry point for completion: it owns the guards, the state
    /// write and the choreography, so no caller can produce a celebration
    /// without the persisted change that earns it.
    ///
    /// - Parameters:
    ///   - questID: the task to complete.
    ///   - reward: XP awarded. Stored on the record so past days keep the value
    ///     they were worth at the time.
    private func completeTask(_ questID: String, reward: Int) {
        guard let quest = Quest.all.first(where: { $0.id == questID }) else { return }
        // Already done, or a second tap landed while the first was in flight.
        guard quest.kind == .manual, !isComplete(quest), !inFlight.contains(questID) else { return }

        let levelBefore = LevelProgress.forXP(totalXP).level

        inFlight.insert(questID)
        context.insert(QuestCompletion(questID: questID, day: today, xp: reward))
        try? context.save()

        // Keep the row up while the tick, burst and reward play out.
        lingering.insert(questID)
        celebratingQuestID = questID
        rewardLabels[questID] = "+\(reward) XP"
        celebrationIDs[questID, default: 0] += 1

        let levelAfter = LevelProgress.forXP(totalXP).level
        if levelAfter > levelBefore {
            levelUpTo = levelAfter
            levelUpID += 1
        }

        Task {
            // Main beat: tick, pop, particles, reward. Then the row leaves.
            try? await Task.sleep(for: .milliseconds(760))
            withAnimation(.smooth(duration: 0.45)) {
                _ = lingering.remove(questID)
            }
            celebratingQuestID = nil
            inFlight.remove(questID)

            // The level banner outlasts the row so it is not cut short.
            try? await Task.sleep(for: .milliseconds(900))
            levelUpTo = nil
        }
    }
}
