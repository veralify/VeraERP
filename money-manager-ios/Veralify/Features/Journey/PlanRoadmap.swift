import SwiftUI
import SwiftData
import VeralifyCore

/// The payoff plan as a route rather than a table: one stop per month, the
/// road filled in behind you and dim ahead, with a badge where a debt clears
/// and a flag at the end.
///
/// A section, not a screen. It used to be its own tab, which meant the plan was
/// answered in two places: the months here, and what they cost under "Where it
/// goes". Neither was the whole plan. It now sits at the top of that screen's
/// whole-plan scope, above the figures it produces, so there is one place that
/// answers "what is the plan" from first month to last euro.
///
/// It draws no background and no scroll view — its host owns both.
///
/// Every figure comes from `JourneyBuilder`, which reads the same plan the
/// dashboard does — the roadmap is a way of looking at the plan, not a second
/// opinion about it.
struct PlanRoadmap<Middle: View>: View {
    /// What the host wants shown between the payoff card and the first month.
    ///
    /// The alternative was for the host to draw the roadmap's three opening
    /// cards itself so it could slot its own in — which would have meant the
    /// plan's header living in a screen about cash flow.
    private let middle: Middle

    init(@ViewBuilder middle: () -> Middle) { self.middle = middle() }

    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.modelContext) private var context
    @State private var isAdjusting = false
    @State private var isExporting = false

    /// Everything the screen draws, worked out in one pass.
    ///
    /// These used to be computed properties, so each read redid the work — and
    /// deciding a row's state read one of them, once per row. Building the whole
    /// lot once per render and handing it down keeps a segmented-control tap
    /// from re-running the payoff engine a dozen times.
    private struct Roadmap {
        let dashboard: DashboardSummary
        let steps: [JourneyStep]
        let analytics: JourneySummary
        /// The stretch past the finish line, when the plan clears the debt
        /// before its target period is up.
        let afterPayoff: JourneyAfterPayoff?
        /// Where the user is now. Steps before it are behind them.
        let currentIndex: Int

        /// How far along the route, not how much of the debt the plan expects to
        /// clear. `DashboardSummary.progressFraction` answers the second
        /// question — for a feasible plan it is 100% on day one, which is true
        /// of the plan and nonsense as a position on a map.
        var routeProgress: Double {
            guard !steps.isEmpty else { return 0 }
            return Double(currentIndex) / Double(steps.count)
        }
    }

    @MainActor
    private func makeRoadmap() -> Roadmap {
        let dashboard = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first
        )
        let values = debts.map(\.asDebt)
        let steps = JourneyBuilder.steps(plan: dashboard.plan, debts: values)
        let key = JourneyStep.monthKey(for: .now)

        return Roadmap(
            dashboard: dashboard,
            steps: steps,
            analytics: JourneyBuilder.summary(plan: dashboard.plan, debts: values),
            afterPayoff: JourneyBuilder.afterPayoff(plan: dashboard.plan, debts: values),
            currentIndex: steps.firstIndex { $0.month >= key } ?? max(0, steps.count - 1)
        )
    }

    var body: some View {
        let roadmap = makeRoadmap()

        return Group {
            if roadmap.steps.isEmpty {
                EmptyStateView(
                    icon: "map",
                    title: "No route yet",
                    message: "Add a debt and a target period and your roadmap appears here."
                )
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 0) {
                    header(roadmap)
                        .padding(.bottom, 14)

                    planActions
                        .padding(.bottom, 16)

                    if let after = roadmap.afterPayoff {
                        afterPayoffCard(after)
                            .padding(.bottom, 20)
                    }

                    middle
                        .padding(.bottom, 20)

                    routeContent(roadmap)
                        .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $isAdjusting) {
            AdjustPlanSheet().presentationBackground(Theme.background)
        }
        .sheet(isPresented: $isExporting) {
            PlanExportSheet().presentationBackground(Theme.background)
        }
    }

    /// The months themselves.
    ///
    /// These were one-line steps on a rail, which said the month, the payment
    /// and two figures and made you push to a second screen for the other two.
    /// The card carries all four, so the push is gone and the list is the plan.
    @ViewBuilder
    private func routeContent(_ roadmap: Roadmap) -> some View {
        let months = PlanMonthCard.months(
            steps: roadmap.steps,
            totalDebt: roadmap.dashboard.plan.totalDebt,
            spare: roadmap.dashboard.totalIncome - roadmap.dashboard.totalExpenses
        )

        PlanConstants(
            income: roadmap.dashboard.totalIncome,
            expenses: roadmap.dashboard.totalExpenses
        )
        .padding(.bottom, 26)

        // Spacing 0 and the gap carried by each card's own bottom padding, so
        // the rail beside it can run through that gap unbroken. A LazyVStack
        // gap would cut the line into thirteen pieces.
        LazyVStack(spacing: 0) {
            ForEach(Array(months.enumerated()), id: \.element.id) { position, month in
                let isLast = position == months.count - 1

                HStack(alignment: .top, spacing: 12) {
                    rail(
                        position: position,
                        currentIndex: roadmap.currentIndex,
                        step: month.step,
                        isLast: isLast
                    )

                    PlanMonthCard(
                        month: month,
                        isBehind: position < roadmap.currentIndex,
                        isCurrent: position == roadmap.currentIndex
                    )
                    .padding(.bottom, isLast ? 0 : 14)
                }
            }
        }

        if !roadmap.dashboard.plan.isFeasible {
            infeasibleNote(roadmap)
                .padding(.top, 20)
        }
    }

    /// The road beside the months: where you have been, where you are, and how
    /// much of it is still ahead.
    ///
    /// The cards say what each month does; the rail says where the month sits.
    /// Neither answers the other's question, which is why the rail came back
    /// when the one-line steps became cards.
    private func rail(
        position: Int,
        currentIndex: Int,
        step: JourneyStep,
        isLast: Bool
    ) -> some View {
        let isDone = position < currentIndex
        let isCurrent = position == currentIndex

        return VStack(spacing: 0) {
            node(isDone: isDone, isCurrent: isCurrent, step: step, position: position)

            if !isLast {
                Rectangle()
                    .fill(isDone ? Theme.green : Theme.stroke)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 34)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func node(isDone: Bool, isCurrent: Bool, step: JourneyStep, position: Int) -> some View {
        ZStack {
            Circle()
                .fill(isDone ? Theme.green : isCurrent ? .white : Theme.surface)

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.onAccent)
            } else if isCurrent {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            } else if step.isFinish {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text("\(position + 1)")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 34, height: 34)
        .overlay(
            Circle().strokeBorder(
                isCurrent ? Theme.lime : .clear,
                lineWidth: 2
            )
        )
    }

    /// What the plan builds after the last debt goes.
    ///
    /// The route used to stop at the finish line, which hid the best part: a
    /// sixteen-month plan that clears the debt in thirteen has three months
    /// where the whole payment stops leaving and starts piling up instead.
    ///
    /// It sits above the route rather than after it: the payoff is the reason
    /// to read the thirteen rows, so it should not be the reward for having
    /// scrolled past them. That puts it directly under the lime hero, so it is
    /// drawn on the surface colour with lime only on the figure — two solid
    /// lime blocks in a row read as one undifferentiated panel.
    private func afterPayoffCard(_ after: JourneyAfterPayoff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 34, height: 34)
                    .background(Theme.lime.opacity(0.16), in: .rect(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Then it's yours")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(after.months) months left of your plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CurrencyFormat.string(after.accumulated))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.lime)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("by \(JourneyStep.title(for: after.endMonth))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            // One row, not three. "In hand at the end" is the same euro figure
            // as the tile below this card, and the finish balance is the last
            // row of the route — a card that repeats its neighbours is length
            // without information.
            afterRow(
                "Free each month",
                CurrencyFormat.string(after.monthlySurplus),
                detail: String(localized: "no payment leaving")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func afterRow(_ label: LocalizedStringKey, _ value: String, detail: String?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            if let detail {
                // Two views rather than one interpolated string: "· %@" is a
                // separator, not a phrase worth handing to a translator.
                Group {
                    Text("·")
                    Text(detail).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
    }

    /// The two things you do to a plan rather than read from it.
    ///
    /// The settings used to sit loose at the foot of the route as a card you
    /// scrolled past. They are actions, not content, so they are buttons — and
    /// the full set now lives behind one of them instead of only the two dials
    /// that happened to fit.
    ///
    /// They sit above the route, not below it: thirteen steps is a long way to
    /// scroll to reach a button, and on a longer plan it is longer still.
    private var planActions: some View {
        HStack(spacing: 10) {
            Button { isAdjusting = true } label: {
                actionLabel("Adjust plan", icon: "slider.horizontal.3", isPrimary: true)
            }
            .buttonStyle(.pressable)

            Button { isExporting = true } label: {
                actionLabel("Export", icon: "square.and.arrow.up", isPrimary: false)
            }
            .buttonStyle(.pressable)
        }
    }

    private func actionLabel(
        _ title: LocalizedStringKey,
        icon: String,
        isPrimary: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(isPrimary ? Theme.onAccent : Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isPrimary ? Theme.lime : Theme.surface, in: .capsule)
        .overlay(
            Capsule().strokeBorder(isPrimary ? .clear : Theme.stroke, lineWidth: 1)
        )
    }

    private func header(_ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Step \(roadmap.currentIndex + 1)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                Text("of \(roadmap.steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.8))
                Spacer(minLength: 0)
                Text(CurrencyFormat.string(roadmap.steps[roadmap.currentIndex].remainingDebt))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            ProgressTrack(progress: roadmap.routeProgress)

            // One pill, not two: "13 months" only restated the "of 13" a line
            // above it, and a finish date is the thing people actually repeat
            // to each other.
            HStack(spacing: 10) {
                if let finish = roadmap.analytics.finishMonth {
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

    private func infeasibleNote(_ roadmap: Roadmap) -> some View {
        let plan = roadmap.dashboard.plan
        return AlertBanner(
            icon: "exclamationmark.triangle.fill",
            title: "This route doesn't reach the end",
            message: "At \(CurrencyFormat.string(plan.usedMonthly)) a month you'd still owe \(CurrencyFormat.string(plan.projectedRemaining)) after \(plan.targetMonths) months. Lengthen the target period or free up more each month.",
            accent: Theme.yellow
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
