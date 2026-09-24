import Foundation
import SwiftUI
import SwiftData
import VeralifyCore

/// Confirms a move of money to or from one debt.
///
/// The drag picks the debt and the direction; this picks the amount, because a
/// finger cannot pick a figure to the euro. It states the new monthly payment
/// before committing, so nothing about the plan changes without being shown.
struct AllocateSheet: View {
    let debt: DebtRecord
    /// True when money is going to the debt.
    let toward: Bool
    /// The most that can move: the leftover, or the room above interest.
    let ceiling: Decimal
    /// When set, the money is moving from this other debt's extra rather than
    /// from the leftover pool — a debt was dragged onto a debt.
    var counterpart: DebtRecord? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var amount: Double = 0
    @State private var hasOpened = false
    /// The lender's figure, edited as text because it is typed from a
    /// statement rather than dragged to.
    @State private var minimumText = ""

    private var maximum: Double { max(ceiling.chartValue, 0) }

    /// €5 notches, unless the whole range is smaller than that — a step wider
    /// than the bounds is the precondition `Slider` traps on.
    private var step: Double { maximum >= 5 ? 5 : max(maximum / 10, 0.01) }
    private var moved: Decimal { Decimal(amount.rounded()) }

    /// What the user has chosen to add on top, after this move.
    private var newExtra: Decimal {
        max(toward ? debt.extraPayment + moved : debt.extraPayment - moved, 0)
    }

    private var editedMinimum: Decimal {
        Decimal(string: minimumText.replacingOccurrences(of: ",", with: "."))
            ?? debt.minimumPayment
    }

    private var newPayment: Decimal { editedMinimum + newExtra }

    private var subtitle: LocalizedStringKey {
        if let counterpart {
            return "Moved from what you overpay on \(counterpart.name)."
        }
        return toward
            ? "Moved out of what is left over this month."
            : "Given back to what is left over this month."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toward ? "Pay more on \(debt.name)" : "Pay less on \(debt.name)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 10) {
                Text(CurrencyFormat.string(moved))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(toward ? Theme.lime : Theme.yellow)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: amount)
                    .frame(maxWidth: .infinity)

                // No range, no slider. `Slider` traps at init when the step is
                // wider than the bounds, and a debt paid at exactly its
                // minimum gives bounds of zero — which crashed the app the
                // moment that debt was dragged onto the leftover.
                if maximum > 0 {
                    Slider(value: $amount, in: 0...maximum, step: step)
                        .tint(toward ? Theme.lime : Theme.yellow)

                    HStack {
                        Text(CurrencyFormat.string(0))
                        Spacer()
                        Text(CurrencyFormat.string(ceiling))
                    }
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            GroupedCard {
                // The minimum is the one figure here the app does not get to
                // decide, so it is typed rather than dragged — and it is on
                // this screen because this is where its consequences show.
                HStack {
                    Text("Minimum payment")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    // The symbol sits outside the field so the value stays a
                    // plain number to type into, and still reads as money. The
                    // pair is sized to its content so the symbol stays against
                    // the digits instead of drifting to the far side of a
                    // fixed-width field.
                    HStack(spacing: 2) {
                        Text(CurrencyFormat.symbol)
                            .foregroundStyle(Theme.textTertiary)
                        TextField(
                            NSDecimalNumber(decimal: debt.minimumPayment).stringValue,
                            text: $minimumText
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize()
                    }
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                }
                .padding(.vertical, 12)

                RowDivider()
                row("Extra each month", CurrencyFormat.string(newExtra), tint: Theme.textSecondary)
                RowDivider()
                row("Total each month", CurrencyFormat.string(newPayment), tint: Theme.textPrimary)
            }

            if maximum <= 0 {
                Text(
                    toward
                        ? "There is nothing left over to move this month."
                        : "You are only paying the minimum on this one, so there is nothing extra to take back."
                )
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // A swipe rather than a tap, for the same reason the entry sheet
            // uses one: this writes a change to the plan, and a stray tap on a
            // sheet that arrived under your finger should not be able to.
            SwipeToConfirm(
                title: "Swipe to apply",
                accent: toward ? Theme.lime : Theme.yellow,
                enabled: moved > 0 || editedMinimum != debt.minimumPayment
            ) {
                debt.minimumPayment = max(editedMinimum, 0)
                debt.extraPayment = newExtra
                // Debt-to-debt: the money it gains is money the other debt
                // gives up, so the leftover total does not move.
                if let counterpart {
                    counterpart.extraPayment = max(counterpart.extraPayment - moved, 0)
                }
                try? context.save()
                dismiss()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .presentationDragIndicator(.visible)
        .task {
            // Opening on zero makes the sheet arrive already disabled, with
            // nothing to look at. Half the room is an obviously adjustable
            // starting point rather than a recommendation.
            guard !hasOpened else { return }
            hasOpened = true
            amount = min((maximum / 2 / step).rounded(.down) * step, maximum)
            minimumText = NSDecimalNumber(decimal: debt.minimumPayment).stringValue
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.vertical, 12)
    }
}
