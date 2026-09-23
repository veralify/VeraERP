import SwiftUI
import SwiftData
import Charts
import VeralifyCore

/// What you actually spent, by category.
///
/// The ledger has carried a category on every entry since it was built and
/// nothing ever showed it. This is the first screen that gives those entries a
/// reason to exist: the plan says what should happen every month, and this says
/// what did.
struct SpendingByCategory: View {
    /// Everything ever recorded; the timeframe decides what counts.
    let entries: [TransactionRecord]
    @Binding var direction: EntryDirection
    @Binding var timeframe: Timeframe

    @Query(sort: \CategoryBudget.limit, order: .reverse) private var budgets: [CategoryBudget]

    private var window: DateInterval? { timeframe.interval(containing: .now) }

    private var matching: [TransactionRecord] {
        entries.filter {
            $0.direction == direction && timeframe.contains($0.occurredAt)
        }
    }

    private var shares: [CategoryShare] {
        CategoryBreakdown.ranked(
            matching.map { (category: $0.category, amount: $0.amount) },
            otherLabel: String(localized: "Everything else")
        )
    }

    private var total: Decimal { CategoryBreakdown.total(shares) }

    var body: some View {
        VStack(spacing: 18) {
            TimeframeButton(timeframe: $timeframe)

            Picker("Direction", selection: $direction) {
                ForEach(EntryDirection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if shares.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "Nothing in this period",
                    message: "Pick a longer time frame, or tap Add and record something."
                )
            } else {
                ring
                list
                // Only on spending: a budget on money coming in is not a thing.
                if direction == .debit { budgetLink }
            }
        }
    }

    // MARK: - The ring

    /// A ring, not a bar: these are parts of one month's spending and there are
    /// up to six of them, which is more than a stacked bar can label. The total
    /// sits in the hole, where it is the first thing read.
    private var ring: some View {
        Chart(Array(shares.enumerated()), id: \.element.id) { index, share in
            SectorMark(
                angle: .value("Amount", share.total.chartValue),
                innerRadius: .ratio(0.62),
                // The 2pt gap between segments that a border would otherwise
                // have to draw.
                angularInset: 1.6
            )
            .foregroundStyle(colour(for: index, share: share))
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(direction == .debit ? "Spent" : "Received")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(CurrencyFormat.string(total))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 30)
            }
        }
        .frame(height: 220)
    }

    // MARK: - The list

    /// The legend and the detail in one: colour, name, how many entries, the
    /// amount and its share. A separate legend box would say less and take the
    /// same room.
    private var list: some View {
        GroupedCard {
            ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                if index > 0 { RowDivider() }

                if share.isOther {
                    row(share, colour: colour(for: index, share: share))
                } else {
                    NavigationLink(value: route(for: share)) {
                        row(share, colour: colour(for: index, share: share))
                    }
                    .buttonStyle(.pressableRow)
                }

                if let line = line(for: share) { budgetBar(line) }
            }
        }
    }

    private func row(_ share: CategoryShare, colour: Color) -> some View {
        HStack(spacing: 12) {
            if share.isOther {
                Circle().fill(colour).frame(width: 9, height: 9).frame(width: 30)
            } else {
                CategoryStyle.badge(share.name, size: 30)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(share.name))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(share.count) entries")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormat.string(share.total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("\(percent(share))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(share.isOther ? .clear : Theme.textTertiary)
        }
        .padding(.vertical, 11)
        // Without this the link only answers to taps that land on a glyph:
        // the gaps between the badge, the labels and the amount are not part
        // of the rendered content and so are not part of the target.
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// Under a row that has a limit: how far through it this spending is. The
    /// same bar as the Budgets screen, so the two cannot disagree.
    private func budgetBar(_ line: BudgetLine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ProgressTrack(
                progress: line.fraction,
                foreground: line.isOver ? Theme.red : Theme.lime,
                fill: line.isOver ? Theme.red : Theme.lime
            )
            Text(line.isOver
                 ? "\(CurrencyFormat.string(-line.remaining)) over the \(CurrencyFormat.string(line.limit)) limit"
                 : "\(CurrencyFormat.string(line.remaining)) left of \(CurrencyFormat.string(line.limit))")
                .font(.caption2)
                .foregroundStyle(line.isOver ? Theme.red : Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.bottom, 11)
    }

    /// The way into budgets, carrying the one fact worth knowing from here.
    private var budgetLink: some View {
        let report = BudgetTracker.report(
            budgets: budgets.map { (category: $0.category, limit: $0.limit) },
            entries: matching.map { (category: $0.category, amount: $0.amount) }
        )

        return NavigationLink(value: BudgetsRoute()) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.horizontal.page")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(report.overCount > 0 ? Theme.red : Theme.lime)
                    .frame(width: 32, height: 32)
                    .background(
                        (report.overCount > 0 ? Theme.red : Theme.lime).opacity(0.14),
                        in: .rect(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Budgets")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(budgetCaption(report))
                        .font(.caption)
                        .foregroundStyle(report.overCount > 0 ? Theme.red : Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.pressable)
    }

    private func budgetCaption(_ report: BudgetReport) -> LocalizedStringKey {
        if report.isEmpty { return "Set a limit on a category" }
        if report.overCount > 0 { return "\(report.overCount) over their limit" }
        return "\(CurrencyFormat.string(report.totalRemaining)) left this month"
    }

    /// The limit on this category, when there is one.
    private func line(for share: CategoryShare) -> BudgetLine? {
        guard direction == .debit, !share.isOther,
              let budget = budgets.first(where: { $0.category == share.name })
        else { return nil }

        return BudgetLine(
            category: share.name, limit: budget.limit, spent: share.total, count: share.count
        )
    }

    /// By category, never by rank. Colouring the slices in ranked order meant
    /// Food and Bills swapped colours the month one overtook the other.
    private func colour(for index: Int, share: CategoryShare) -> Color {
        share.isOther ? Theme.categoricalOther : CategoryStyle.colour(share.name)
    }

    private func route(for share: CategoryShare) -> CategoryRoute {
        CategoryRoute(
            category: share.name,
            direction: direction,
            from: window?.start,
            to: window?.end
        )
    }

    private func percent(_ share: CategoryShare) -> Int {
        guard total > 0 else { return 0 }
        return Int(((share.total / total).chartValue * 100).rounded())
    }
}
