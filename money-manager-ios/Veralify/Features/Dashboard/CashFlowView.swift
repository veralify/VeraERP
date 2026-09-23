import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for the cash-flow breakdown.
struct CashFlowRoute: Hashable {}

/// Where the money goes — this month, and over the whole plan.
///
/// Rebuilt from three stacked cards that had nothing to do with each other: a
/// monthly breakdown, a Sankey of the same month, and a multi-year payoff chart,
/// one after another with no separation. Two questions were being answered on
/// one scroll, so neither read as an answer.
///
/// Now it is one scope control and two reports that share a shape: a sentence
/// saying what the figures mean, one picture, and a ranked list underneath. The
/// order is deliberate — you should be able to stop after the sentence.
struct CashFlowView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var transactions: [TransactionRecord]

    /// Which report opens first. The tab lands on the whole plan; the links
    /// from Today land on the month they were tapped from.
    /// A pushed copy names itself; the copy that is the Plan tab does not,
    /// because `MainTabView` already owns that bar and two views writing to it
    /// is a race, not a title.
    private let ownsTitle: Bool

    init(scope: Scope = .month, ownsTitle: Bool = true) {
        _scope = State(initialValue: scope)
        self.ownsTitle = ownsTitle
    }

    @State private var scope: Scope
    @State private var direction: EntryDirection = .debit
    @State private var timeframe: Timeframe = .month

    enum Scope: Int, CaseIterable, Identifiable {
        case month, spending, plan
        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .month:    "Planned"
            case .spending: "Spent"
            case .plan:     "Whole plan"
            }
        }
    }

    /// Worked out once per render and handed down. The payoff engine bisects
    /// fifty times, and three of these sections want the same plan.
    private struct Analysis {
        let dashboard: DashboardSummary
        let steps: [JourneyStep]
        let journey: JourneySummary
        let afterPayoff: JourneyAfterPayoff?
        let currentIndex: Int
    }

    @MainActor
    private func analysis() -> Analysis {
        let dashboard = DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first
        )
        let values = debts.map(\.asDebt)
        let steps = JourneyBuilder.steps(plan: dashboard.plan, debts: values)
        let key = JourneyStep.monthKey(for: .now)

        return Analysis(
            dashboard: dashboard,
            steps: steps,
            journey: JourneyBuilder.summary(plan: dashboard.plan, debts: values),
            afterPayoff: JourneyBuilder.afterPayoff(plan: dashboard.plan, debts: values),
            currentIndex: steps.firstIndex { $0.month >= key } ?? max(0, steps.count - 1)
        )
    }

    var body: some View {
        let analysis = analysis()

        return ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Picker("Scope", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch scope {
                    case .month:    monthReport(analysis.dashboard)
                    case .spending:
                        SpendingByCategory(
                            entries: transactions,
                            direction: $direction,
                            timeframe: $timeframe
                        )
                    case .plan:     planReport(analysis)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 108)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(ownsTitle ? Text("Where it goes") : Text(""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - This month

    @ViewBuilder
    private func monthReport(_ summary: DashboardSummary) -> some View {
        let outgoing = summary.totalExpenses + summary.totalDebtMinimums

        VStack(spacing: 18) {
            headline(
                amount: summary.netCashFlow,
                caption: summary.totalIncome > 0
                    ? String(
                        localized: "left of the \(CurrencyFormat.string(summary.totalIncome)) that comes in"
                      )
                    : String(localized: "no income recorded yet"),
                accent: summary.netCashFlow >= 0 ? Theme.lime : Theme.red
            )

            // A stacked bar rather than a ring: these are three parts of one
            // month's income, and a bar reads in the same order as the rows
            // beneath it. A ring also wraps, which would put the lime segment
            // against the yellow one — a pair nobody can tell apart, colour
            // vision or not.
            SplitBar(segments: [
                .init(value: summary.totalExpenses, colour: Theme.yellow),
                .init(value: summary.totalDebtMinimums, colour: Theme.red),
                .init(value: max(summary.netCashFlow, 0), colour: Theme.lime)
            ])

            GroupedCard {
                shareRow(
                    kind: .expense,
                    title: "Core expenses",
                    amount: summary.totalExpenses,
                    share: share(summary.totalExpenses, of: summary.totalIncome),
                    colour: Theme.yellow
                )
                RowDivider()
                shareRow(
                    kind: .debt,
                    title: "Debt payments",
                    amount: summary.totalDebtMinimums,
                    share: share(summary.totalDebtMinimums, of: summary.totalIncome),
                    colour: Theme.red
                )
                RowDivider()
                shareRow(
                    kind: nil,
                    title: "Left over",
                    amount: summary.netCashFlow,
                    share: share(summary.netCashFlow, of: summary.totalIncome),
                    colour: Theme.lime
                )
            }

            if summary.netCashFlow < 0 {
                AlertBanner(
                    icon: "exclamationmark.triangle.fill",
                    title: "You are spending more than you earn",
                    message: "\(CurrencyFormat.string(outgoing)) goes out against \(CurrencyFormat.string(summary.totalIncome)) coming in. Until that closes, the payoff plan cannot hold.",
                    accent: Theme.red
                )
            }

            footnote("Debt payments count here because they are due every month, the same as rent. Anything you pay above the minimum comes out of what is left.")
        }
    }

    // MARK: - Whole plan

    @ViewBuilder
    private func planReport(_ analysis: Analysis) -> some View {
        if analysis.steps.isEmpty {
            EmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "No plan to analyse",
                message: "Add a debt and Veralify works out what clearing it costs."
            )
        } else {
            // One reading order, top to bottom: where you stand, what you can
            // do about it, what it leaves you, the three figures that describe
            // it, the shape of it, then every month and every debt.
            //
            // The big "total paid" figure and the interest card that used to
            // sit here are gone into the tiles. Both were a single number in a
            // block of their own, and stacked with the hero and the payoff card
            // they made four headline figures competing above one chart.
            VStack(spacing: 18) {
                PlanRoadmap {
                    VStack(spacing: 14) {
                        planStats(analysis)

                        // No longer a link: the months it used to push to are
                        // the cards directly below this chart.
                        PlanCurves(steps: analysis.steps, currentIndex: analysis.currentIndex)
                    }
                }

                SectionHeader(title: "Debt by debt") { EmptyView() }

                DebtCostTable(perDebt: analysis.journey.perDebt, debts: debts)

                footnote("Totals cover the months the plan actually runs for. A debt the plan does not reach is marked as such rather than counted.")
            }
        }
    }

    /// Three figures, equal weight, one line each.
    ///
    /// What it costs you every month, what the borrowing costs in total, and
    /// what is left when it is over — the answer to "should I keep going" in
    /// the width of the screen.
    private func planStats(_ analysis: Analysis) -> some View {
        HStack(spacing: 10) {
            statTile(
                "Each month",
                CurrencyFormat.string(analysis.dashboard.plan.requiredMonthly),
                colour: Theme.textPrimary
            )
            statTile(
                "Interest",
                CurrencyFormat.string(analysis.journey.totalInterest),
                colour: Theme.red
            )
            statTile(
                "Yours at the end",
                CurrencyFormat.string(
                    analysis.afterPayoff?.balanceAtEnd
                        ?? analysis.steps.last?.cumulativeBalance ?? 0
                ),
                colour: Theme.lime
            )
        }
    }

    private func statTile(
        _ label: LocalizedStringKey,
        _ value: String,
        colour: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colour)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Theme.surface, in: .rect(cornerRadius: 14))
    }

    // MARK: - Shared pieces

    /// The one number the report is about, big and alone. Everything under it
    /// explains it; nothing above it competes with it.
    private func headline(amount: Decimal, caption: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(CurrencyFormat.string(amount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// A destination, its share, and the way into the records behind it.
    private func shareRow(
        kind: EntryKind?,
        title: LocalizedStringKey,
        amount: Decimal,
        share: Int,
        colour: Color
    ) -> some View {
        let content = HStack(spacing: 12) {
            Circle()
                .fill(colour)
                .frame(width: 9, height: 9)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("\(share)%")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)

            Spacer(minLength: 8)

            Text(CurrencyFormat.string(amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(kind == nil ? .clear : Theme.textTertiary)
        }
        .padding(.vertical, 13)
        .contentShape(.rect)

        return Group {
            if let kind {
                NavigationLink(value: kind) { content }
                    .buttonStyle(.pressableRow)
            } else {
                content
            }
        }
    }

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func share(_ part: Decimal, of whole: Decimal) -> Int {
        guard whole > 0 else { return 0 }
        return Int(((part / whole).chartValue * 100).rounded())
    }
}

// MARK: - The bar

/// One total, split into its parts.
///
/// Segments are separated by a 2pt gap in the surface colour rather than butted
/// together: adjacent fills of similar lightness read as one block without it,
/// and the gap does the job a border would without adding another line.
struct SplitBar: View {
    struct Segment {
        let value: Decimal
        let colour: Color
    }

    let segments: [Segment]
    var height: CGFloat = 14

    private var total: Decimal { segments.reduce(Decimal(0)) { $0 + max($1.value, 0) } }

    var body: some View {
        GeometryReader { geometry in
            let gaps = CGFloat(max(segments.count - 1, 0)) * 2
            let usable = max(geometry.size.width - gaps, 0)

            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let fraction = total > 0 ? (max(segment.value, 0) / total).chartValue : 0
                    Capsule()
                        .fill(segment.colour)
                        .frame(width: usable * fraction)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
