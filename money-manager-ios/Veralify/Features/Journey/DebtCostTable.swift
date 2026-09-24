import SwiftUI
import VeralifyCore

/// Every debt, on one row each: what is owed now, what the rate is, what it will
/// cost in total, and when it goes.
///
/// This replaces two cards that each told half of it — a "debts by balance" bar
/// chart that ranked them by size, and a "where the money goes" list that ranked
/// them by total paid. Neither answered "which of these is actually hurting me",
/// because the balance and the interest were never on the same row.
///
/// The bar is the one piece of the old design worth keeping: it splits what you
/// borrowed from what the borrowing cost, and the second number is the one worth
/// acting on. Its colours are fixed rather than one-per-debt — a rotating
/// palette made the colour look like it meant something about the debt, when it
/// only meant "the third one".
struct DebtCostTable: View {
    let perDebt: [JourneyDebtTotal]
    let debts: [DebtRecord]

    private var widest: Decimal { perDebt.map(\.paid).max() ?? 1 }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(perDebt) { total in
                row(total)
            }

            // A key to bars that are not there is a stray line of text.
            if !perDebt.isEmpty {
                legend
            }
        }
    }

    private func row(_ total: JourneyDebtTotal) -> some View {
        let debt = debts.first { $0.remoteID == total.id }

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalizedStringKey(total.name))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let apr = debt?.apr, apr > 0 {
                    Text("\(apr.percentText)%")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.red.opacity(0.14), in: .capsule)
                        // A rate wrapped onto two lines inside a capsule reads
                        // as a broken pill; the name gives way instead.
                        .fixedSize()
                }

                Spacer(minLength: 8)

                // The column every row is compared on: always whole, always
                // against the trailing edge.
                Text(CurrencyFormat.string(total.paid))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            GeometryReader { geometry in
                let width = geometry.size.width * (total.paid / widest).chartValue
                let interest = total.paid > 0
                    ? width * (total.interest / total.paid).chartValue
                    : 0

                // One rounded bar with two flat segments inside it, rather than
                // two capsules side by side: a capsule a few points wide renders
                // as a dot, so a small interest share looked like a bullet
                // stuck on the end instead of part of the bar.
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.lime)
                        .frame(width: max(0, width - interest))
                    Rectangle().fill(Theme.red)
                        .frame(width: max(0, interest))
                    Spacer(minLength: 0)
                }
                .clipShape(.capsule)
            }
            .frame(height: 7)

            // Three facts on one line when they fit. On a small phone, or in
            // a longer language, they did not, and the date at the end was
            // the one truncated — so it moves to a line of its own instead.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    amounts(total, balance: debt?.balance)
                    Spacer(minLength: 4)
                    clearance(total)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        amounts(total, balance: debt?.balance)
                    }
                    clearance(total)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func amounts(_ total: JourneyDebtTotal, balance: Decimal?) -> some View {
        if let balance {
            Text("\(CurrencyFormat.string(balance)) left")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }

        if total.interest > 0 {
            Text("\(CurrencyFormat.string(total.interest)) interest")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.red)
        }
    }

    @ViewBuilder
    private func clearance(_ total: JourneyDebtTotal) -> some View {
        if let cleared = total.clearedMonth {
            Text("gone by \(JourneyStep.title(for: cleared))")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        } else {
            Text("not cleared in this plan")
                .font(.caption2)
                .foregroundStyle(Theme.yellow)
        }
    }

    /// Wraps rather than squeezes: at larger text sizes the two keys do not
    /// share one line on a phone.
    private var legend: some View {
        FlowRow(spacing: 14) {
            key("What you borrowed", Theme.lime)
            key("What it costs you", Theme.red)
        }
        .padding(.horizontal, 4)
    }

    private func key(_ label: LocalizedStringKey, _ colour: Color) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(colour).frame(width: 12, height: 4)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
