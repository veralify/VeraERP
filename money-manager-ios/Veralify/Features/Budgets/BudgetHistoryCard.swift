import SwiftUI
import SwiftData
import Charts
import VeralifyCore

/// How the last six months went, in a sentence and a chart.
///
/// The sentence first, because it is the whole answer for most people: whether
/// the budgets hold, by how much they don't, and how often. The chart is for the
/// follow-up question — which one keeps blowing up.
struct BudgetHistoryCard: View {
    let history: BudgetHistory

    /// Series shown as bars. Six budgets × six months is thirty-six bars across
    /// a phone, which is about four points each — past four categories the
    /// chart stops being readable, so the rest sit out of it. They are still in
    /// the sentence and in the cards below.
    private static let maxSeries = 4

    private var charted: [String] { Array(history.categories.prefix(Self.maxSeries)) }
    private var hidden: Int { max(history.categories.count - Self.maxSeries, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary
            // The legend goes with the chart: on its own it was an empty row
            // that still took the stack's spacing under the sentence.
            if !charted.isEmpty {
                chart
                legend
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    // MARK: - The sentence

    @ViewBuilder
    private var summary: some View {
        let exceeded = history.exceededMonths.count

        VStack(alignment: .leading, spacing: 4) {
            Text("Last \(history.months.count) months")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)

            if let average = history.averageOverspend {
                Text("You went over by \(CurrencyFormat.string(average)) a month on average, in \(exceeded) of them.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("You stayed inside your budgets every month.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - The bars

    /// Grouped bars, one colour per budget, with the total limit as a dashed
    /// rule across them. The rule is what turns a pile of bars into a verdict:
    /// above it is the only part that matters.
    private var chart: some View {
        Chart {
            ForEach(history.months) { month in
                ForEach(Array(charted.enumerated()), id: \.element) { index, category in
                    BarMark(
                        x: .value("Month", shortLabel(month.month)),
                        y: .value("Spent", (month.spentByCategory[category] ?? 0).chartValue),
                        width: .fixed(7)
                    )
                    .position(by: .value("Budget", category))
                    .foregroundStyle(Theme.categorical(index))
                    .cornerRadius(2)
                }
            }

            RuleMark(y: .value("Limit", history.totalLimit.chartValue))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(Theme.red.opacity(0.8))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Limit")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.red)
                }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.stroke)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(CurrencyFormat.compact(Decimal(amount)))
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    /// Identity is never colour alone, so every charted budget is named.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowRow(spacing: 12) {
                ForEach(Array(charted.enumerated()), id: \.element) { index, category in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Theme.categorical(index))
                            .frame(width: 7, height: 7)
                        Text(LocalizedStringKey(category))
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            if hidden > 0 {
                Text("\(hidden) more budgets are counted but not charted.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    /// "Sep" from `2026-09`. The year is on the axis nowhere because six months
    /// never spans two of the same name.
    private func shortLabel(_ month: String) -> String {
        let pieces = month.split(separator: "-")
        guard pieces.count == 2, let number = Int(pieces[1]),
              let date = Calendar.current.date(from: DateComponents(month: number))
        else { return month }
        return date.formatted(.dateTime.month(.abbreviated))
    }
}

/// Wraps its children onto as many lines as they need.
///
/// A legend of four budget names does not fit one line on a phone, and an
/// `HStack` would squeeze them instead of wrapping.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rows: CGFloat = 1
        var x: CGFloat = 0
        var height: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows += 1
                x = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            height = max(height, size.height)
        }

        // Asked for an ideal size (a nil width, as `fixedSize` or
        // `ViewThatFits` do), this used to answer "infinitely wide". The
        // content's own width is the honest answer.
        guard !subviews.isEmpty else { return .zero }
        return CGSize(width: width.isFinite ? width : widest, height: rows * height + (rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
