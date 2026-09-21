import SwiftUI
import Charts
import VeralifyCore

/// What the route costs, drawn from the same plan the steps are.
///
/// Distinct from the Analytics tab, which answers "where does this month's
/// income go". This answers "what does clearing this debt actually cost, and
/// how much of that is the borrowing itself".
struct JourneyAnalytics: View {
    let summary: JourneySummary
    let steps: [JourneyStep]
    let currentIndex: Int

    private var palette: [Color] { [Theme.lime, Theme.blue, Theme.yellow, Theme.red, Theme.green] }

    var body: some View {
        VStack(spacing: 14) {
            statTiles
            balanceChart
            if !summary.perDebt.isEmpty { debtBreakdown }
        }
    }

    // MARK: - Headline figures

    private var statTiles: some View {
        HStack(spacing: 10) {
            // Says over how many months, because on a route that does not
            // reach the end this is what the plan spends, not what is owed.
            StatTile(
                label: "Total to pay",
                value: CurrencyFormat.string(summary.totalPaid),
                caption: String(localized: "over \(steps.count) months"),
                accent: Theme.blue
            )
            StatTile(
                label: "Interest",
                value: CurrencyFormat.string(summary.totalInterest),
                caption: String(localized: "\(Int((summary.interestShare * 100).rounded()))% of it"),
                accent: Theme.red
            )
        }
    }

    // MARK: - Balance over time

    private var balanceChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What you still owe")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            Chart {
                ForEach(steps) { step in
                    AreaMark(
                        x: .value("Step", step.index),
                        y: .value("Owed", step.remainingDebt.chartValue)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.lime.opacity(0.45), Theme.lime.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Step", step.index),
                        y: .value("Owed", step.remainingDebt.chartValue)
                    )
                    .foregroundStyle(Theme.lime)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.monotone)
                }

                // Where the user stands on that curve.
                if steps.indices.contains(currentIndex) {
                    PointMark(
                        x: .value("Step", currentIndex),
                        y: .value("Owed", steps[currentIndex].remainingDebt.chartValue)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(90)
                }
            }
            .chartXAxis(.hidden)
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
            .frame(height: 130)

            HStack {
                Text(JourneyStep.title(for: steps.first?.month ?? ""))
                Spacer(minLength: 8)
                Text(JourneyStep.title(for: steps.last?.month ?? ""))
            }
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Where the money goes

    private var debtBreakdown: some View {
        let largest = summary.perDebt.map(\.paid).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Where the money goes")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ForEach(Array(summary.perDebt.enumerated()), id: \.element.id) { index, debt in
                let accent = palette[index % palette.count]

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LocalizedStringKey(debt.name))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        Text(CurrencyFormat.string(debt.paid))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }

                    // The bar splits into what you borrowed and what the
                    // borrowing cost, because the second number is the one worth
                    // acting on.
                    GeometryReader { geometry in
                        let width = geometry.size.width * (debt.paid / largest).chartValue
                        let interestWidth = debt.paid > 0
                            ? width * (debt.interest / debt.paid).chartValue
                            : 0

                        HStack(spacing: 2) {
                            Capsule().fill(accent)
                                .frame(width: max(0, width - interestWidth))
                            if interestWidth > 1 {
                                Capsule().fill(Theme.red)
                                    .frame(width: interestWidth)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 7)

                    HStack(spacing: 8) {
                        if debt.interest > 0 {
                            Text("\(CurrencyFormat.string(debt.interest)) interest")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.red)
                        } else {
                            Text("No interest")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer(minLength: 4)
                        if let cleared = debt.clearedMonth {
                            Text("clear by \(JourneyStep.title(for: cleared))")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        } else {
                            Text("not cleared in this plan")
                                .font(.caption2)
                                .foregroundStyle(Theme.yellow)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// One headline number with its label.
private struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    var caption: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption ?? " ")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

extension CurrencyFormat {
    /// Short form for a chart axis, where "€15,343.25" does not fit: €15.3k.
    static func compact(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: AppSettings.currencyCode)
                .locale(Locale(identifier: "en_US"))
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

private extension Decimal {
    var chartValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
