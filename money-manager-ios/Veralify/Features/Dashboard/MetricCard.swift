import SwiftUI

/// One headline figure with what it has done since the month began.
///
/// Distinct from `AccentCard`, which colour-blocks the whole surface for the
/// single number that matters most. These sit below it and stay on the neutral
/// surface, so three of them do not compete with the hero — the accent appears
/// only on the icon and the movement chip.
struct MetricCard: View {
    let title: LocalizedStringKey
    let icon: String
    let accent: Color
    let amount: Decimal
    /// `nil` before there is a baseline to compare against.
    let delta: MonthlyDelta?
    /// Whether a rise in this figure is the direction the user wants. Only used
    /// for the arrow's direction; `delta` carries the judgement.
    var risingIsGood: Bool = true
    /// An extra line under the figure, for a card that carries two numbers.
    var footnote: LocalizedStringKey?
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.16), in: .rect(cornerRadius: 8))

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

            Text(CurrencyFormat.string(amount))
                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            changeChip
        }
        .padding(16)
        // Fills the height its row offers, so two cards side by side end
        // level when only one has a movement chip. Content stays at the top.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var changeChip: some View {
        if let delta, !delta.isFlat {
            let tint = delta.isImprovement ? Theme.green : Theme.red
            HStack(spacing: 5) {
                Image(systemName: delta.amount > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .black))
                Text(signedText(delta.amount))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: .capsule)
            .accessibilityLabel(accessibilityChange(delta))
        } else {
            // A month with no movement and a month with nothing to compare
            // against are different states, and saying so costs one line.
            Text(delta == nil ? "Tracking from this month" : "No change this month")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func signedText(_ value: Decimal) -> String {
        // The minus is the typographic one, matching the ledger elsewhere.
        (value > 0 ? "+" : "−") + CurrencyFormat.string(abs(value))
    }

    private func accessibilityChange(_ delta: MonthlyDelta) -> Text {
        delta.amount > 0
            ? Text("Up \(CurrencyFormat.string(abs(delta.amount))) this month")
            : Text("Down \(CurrencyFormat.string(abs(delta.amount))) this month")
    }
}
