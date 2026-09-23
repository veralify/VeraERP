import SwiftUI
import Charts
import VeralifyCore

/// The two curves of a payoff plan: what is still owed, and what is piling up.
///
/// Two charts rather than two lines on one. They were on a shared axis, where
/// €14,000 of debt and €1,300 of cash cannot both be read — the cash line sat
/// flat against the baseline and looked like nothing was happening. Stacked and
/// separately scaled, each one shows its own shape, and the pairing still makes
/// the point: the top falls as the bottom rises.
struct PlanCurves: View {
    let steps: [JourneyStep]
    /// Where the user stands, marked on both curves.
    let currentIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            curve(
                title: "What you still owe",
                colour: Theme.lime,
                value: { $0.remainingDebt }
            )

            Divider().overlay(Theme.stroke)

            curve(
                title: "What you keep",
                colour: Theme.blue,
                value: { $0.cumulativeBalance }
            )

            HStack(spacing: 8) {
                Text(JourneyStep.title(for: steps.first?.month ?? ""))
                Spacer(minLength: 8)
                Text(JourneyStep.title(for: steps.last?.month ?? ""))
            }
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func curve(
        title: LocalizedStringKey,
        colour: Color,
        value: @escaping (JourneyStep) -> Decimal
    ) -> some View {
        let latest = steps.indices.contains(currentIndex) ? steps[currentIndex] : steps.last

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                // Direct label instead of a legend: one series per chart, so
                // the title names it and the number says where it stands now.
                if let latest {
                    Text(CurrencyFormat.string(value(latest)))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(colour)
                }
            }

            Chart {
                ForEach(steps) { step in
                    AreaMark(
                        x: .value("Month", step.index),
                        y: .value("Amount", value(step).chartValue)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [colour.opacity(0.4), colour.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Month", step.index),
                        y: .value("Amount", value(step).chartValue)
                    )
                    .foregroundStyle(colour)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                }

                if let latest {
                    PointMark(
                        x: .value("Month", latest.index),
                        y: .value("Amount", value(latest).chartValue)
                    )
                    .foregroundStyle(Theme.surface)
                    .symbolSize(110)

                    PointMark(
                        x: .value("Month", latest.index),
                        y: .value("Amount", value(latest).chartValue)
                    )
                    .foregroundStyle(colour)
                    .symbolSize(48)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { mark in
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    AxisValueLabel {
                        if let amount = mark.as(Double.self) {
                            Text(CurrencyFormat.compact(Decimal(amount)))
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 96)
        }
        .padding(16)
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
