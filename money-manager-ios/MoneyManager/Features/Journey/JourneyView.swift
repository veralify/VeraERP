import SwiftUI
import SwiftData
import MoneyManagerCore

/// The payoff plan as a route rather than a table: one stop per month, the
/// road filled in behind you and dim ahead, with a badge where a debt clears
/// and a flag at the end.
///
/// Content only: the title, the nav bar and the floating tab bar belong to
/// `MainTabView` so they persist across tab changes.
///
/// Every figure comes from `JourneyBuilder`, which reads the same plan the
/// dashboard does — the roadmap is a way of looking at the plan, not a second
/// opinion about it.
struct JourneyView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    private var steps: [JourneyStep] {
        JourneyBuilder.steps(plan: summary.plan, debts: debts.map(\.asDebt))
    }

    private var analytics: JourneySummary {
        JourneyBuilder.summary(plan: summary.plan, debts: debts.map(\.asDebt))
    }

    /// Where the user is now. Steps before it are behind them.
    private var currentIndex: Int {
        let key = JourneyStep.monthKey(for: .now)
        return steps.firstIndex { $0.month >= key } ?? max(0, steps.count - 1)
    }

    /// How far along the route, not how much of the debt the plan expects to
    /// clear. `DashboardSummary.progressFraction` answers the second question —
    /// for a feasible plan it is 100% on day one, which is true of the plan and
    /// nonsense as a position on a map.
    private var routeProgress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentIndex) / Double(steps.count)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if steps.isEmpty {
                EmptyStateView(
                    icon: "map",
                    title: "No route yet",
                    message: "Add a debt and a target period and your roadmap appears here."
                )
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)

                        JourneyAnalytics(
                            summary: analytics,
                            steps: steps,
                            currentIndex: currentIndex
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)

                        ForEach(Array(steps.enumerated()), id: \.element.id) { position, step in
                            StepRow(
                                step: step,
                                state: state(for: position),
                                isLast: position == steps.count - 1,
                                animate: hasAppeared && !reduceMotion
                            )
                            .padding(.horizontal, 16)
                        }

                        if !summary.plan.isFeasible {
                            infeasibleNote
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.top, 8)
                    // Clear the floating bar so the last stop is never trapped
                    // under it.
                    .padding(.bottom, 108)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            // One frame's grace so the rows animate in rather than appearing
            // already settled.
            try? await Task.sleep(for: .milliseconds(60))
            hasAppeared = true
        }
    }

    private func state(for position: Int) -> StepState {
        if position < currentIndex { .done }
        else if position == currentIndex { .current }
        else { .upcoming }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Step \(currentIndex + 1)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                Text("of \(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.8))
                Spacer(minLength: 0)
                Text(CurrencyFormat.string(steps[currentIndex].remainingDebt))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            ProgressTrack(progress: routeProgress)

            HStack(spacing: 10) {
                Label {
                    Text("\(steps.count) months")
                        .font(.footnote.weight(.bold))
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.onAccent.opacity(0.14), in: .capsule)

                if let finish = analytics.finishMonth {
                    Label {
                        Text(JourneyStep.title(for: finish))
                            .font(.footnote.weight(.bold))
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white, in: .capsule)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var infeasibleNote: some View {
        AlertBanner(
            icon: "exclamationmark.triangle.fill",
            title: "This route doesn't reach the end",
            message: "At \(CurrencyFormat.string(summary.plan.usedMonthly)) a month you'd still owe \(CurrencyFormat.string(summary.plan.projectedRemaining)) after \(summary.plan.targetMonths) months. Lengthen the target period or free up more each month.",
            accent: Theme.yellow
        )
    }
}

enum StepState {
    case done, current, upcoming
}

/// One stop: the node on the road, then the card beside it.
private struct StepRow: View {
    let step: JourneyStep
    let state: StepState
    let isLast: Bool
    let animate: Bool

    private var accent: Color {
        switch state {
        case .done: Theme.green
        case .current: Theme.lime
        case .upcoming: Theme.stroke
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            road
            card
        }
        .opacity(state == .upcoming ? 0.75 : 1)
    }

    /// The node and the segment of road below it. The segment is drawn by the
    /// row above its successor so the line is continuous without a separate
    /// background layer.
    private var road: some View {
        VStack(spacing: 0) {
            ZStack {
                if step.isMilestone {
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 44, height: 44)
                }

                Circle()
                    .fill(state == .upcoming ? Theme.surfaceElevated : accent)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().strokeBorder(
                            state == .current ? .white : .clear,
                            lineWidth: 2
                        )
                    )

                nodeGlyph
            }
            .frame(width: 44, height: 44)

            if !isLast {
                Capsule()
                    .fill(state == .done ? Theme.green : Theme.stroke)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 44)
    }

    @ViewBuilder
    private var nodeGlyph: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.green.readableForeground)
        case .current:
            Image(systemName: step.isFinish ? "flag.checkered" : "figure.walk")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.onAccent)
        case .upcoming:
            if step.isFinish {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("\(step.index + 1)")
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(JourneyStep.title(for: step.month))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(CurrencyFormat.string(step.payment))
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(state == .upcoming ? Theme.textSecondary : Theme.textPrimary)
            }

            // The finish carries a cent of bisection residue that the roadmap
            // already counts as settled. Printing it next to "Debt free" would
            // have the card argue with its own badge.
            Text("\(CurrencyFormat.string(step.isFinish ? 0 : step.remainingDebt)) left after this")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if !step.clearedDebts.isEmpty {
                ForEach(step.clearedDebts, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2.weight(.bold))
                        Text("\(name) paid off")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.yellow, in: .capsule)
                }
            }

            if step.isFinish {
                HStack(spacing: 6) {
                    Image(systemName: "party.popper.fill")
                        .font(.caption2.weight(.bold))
                    Text("Debt free")
                        .font(.caption.weight(.black))
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.lime, in: .capsule)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            step.isMilestone ? Theme.surfaceElevated : Theme.surface,
            in: .rect(cornerRadius: Theme.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(state == .current ? Theme.lime.opacity(0.55) : .clear, lineWidth: 1.5)
        )
        .padding(.bottom, 12)
        .scaleEffect(animate ? 1 : 0.97)
        .opacity(animate ? 1 : 0)
        .animation(
            .smooth(duration: 0.4).delay(Double(min(step.index, 12)) * 0.035),
            value: animate
        )
    }
}

extension JourneyStep {
    /// `yyyy-MM` for a date, matching the engine's month keys so the two can be
    /// compared as strings.
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// "October 2027" from `2027-10`.
    static func title(for month: String) -> String {
        let pieces = month.split(separator: "-")
        guard pieces.count == 2,
              let year = Int(pieces[0]), let monthNumber = Int(pieces[1]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: monthNumber))
        else { return month }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
