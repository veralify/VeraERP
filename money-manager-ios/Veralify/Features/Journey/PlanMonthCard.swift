import SwiftUI
import VeralifyCore

/// One month of the plan, as a card.
///
/// This was a spreadsheet once: nine columns, a pinned month and a sideways
/// scroll. It was a faithful copy of the web app's table and wrong on a phone —
/// you had to scroll right to read a row and left again to see which month it
/// belonged to, and two of the nine columns held the same figure on every line.
///
/// It then became a second thing: a one-line step in the roadmap on one screen
/// and a card on another, so the same month read differently depending on how
/// you arrived at it. There is one month card now, and the roadmap uses it.
struct PlanMonthCard: View {
    /// A step with the two figures the plan does not carry on it worked out.
    struct Month: Identifiable {
        let step: JourneyStep
        /// What came off the balance, interest already netted out.
        let reduction: Decimal
        /// What the month leaves after the payment goes.
        let cashFlow: Decimal

        var id: Int { step.index }
    }

    let month: Month
    /// Dim the months already behind you — the roadmap's one idea, kept.
    var isBehind: Bool = false
    var isCurrent: Bool = false

    var body: some View {
        let step = month.step

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(JourneyStep.title(for: step.month))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 8)

                Text(CurrencyFormat.string(step.payment))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("paid")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            ProgressTrack(progress: step.progress, foreground: Theme.lime, fill: Theme.lime)

            // Two columns of two: four figures is the most a card can carry
            // before it becomes the table this replaced.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    fact("Still owed", CurrencyFormat.string(step.isFinish ? 0 : step.remainingDebt))
                    fact("Cash flow", CurrencyFormat.string(month.cashFlow))
                }
                VStack(alignment: .leading, spacing: 9) {
                    fact("Paid off", CurrencyFormat.string(month.reduction), tint: Theme.green)
                    fact("In hand", CurrencyFormat.string(step.cumulativeBalance), tint: Theme.blue)
                }
            }

            if !step.clearedDebts.isEmpty || step.isFinish {
                FlowRow(spacing: 8) {
                    ForEach(step.clearedDebts, id: \.self) { name in
                        badge("\(name) paid off", icon: "trophy.fill", accent: Theme.yellow)
                    }
                    if step.isFinish {
                        badge("Debt free", icon: "party.popper.fill", accent: Theme.lime)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(border, lineWidth: isCurrent ? 1.5 : 1)
        )
        .opacity(isBehind ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private var border: Color {
        if isCurrent { Theme.lime }
        else if month.step.isMilestone { Theme.lime.opacity(0.45) }
        else { .clear }
    }

    private func fact(
        _ label: LocalizedStringKey,
        _ value: String,
        tint: Color = Theme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(_ title: LocalizedStringKey, icon: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Theme.onAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(accent, in: .capsule)
    }
}

extension PlanMonthCard {
    /// The per-month figures, worked out in one pass down the plan.
    ///
    /// `reduction` needs the previous month's balance and `cashFlow` needs the
    /// household's spare, so neither can be read off a step on its own.
    static func months(steps: [JourneyStep], totalDebt: Decimal, spare: Decimal) -> [Month] {
        var previous = totalDebt
        return steps.map { step in
            let month = Month(
                step: step,
                reduction: previous - step.remainingDebt,
                cashFlow: spare - step.payment
            )
            previous = step.remainingDebt
            return month
        }
    }
}

/// The two figures that never change, said once above the months.
struct PlanConstants: View {
    let income: Decimal
    let expenses: Decimal

    var body: some View {
        HStack(spacing: 0) {
            constant("Income", income, Theme.lime)
            Rectangle().fill(Theme.stroke).frame(width: 1, height: 28)
            constant("Core expenses", expenses, Theme.yellow)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay(alignment: .bottom) {
            Text("the same every month")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .offset(y: 16)
        }
    }

    private func constant(_ label: LocalizedStringKey, _ amount: Decimal, _ accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Text(CurrencyFormat.string(amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
