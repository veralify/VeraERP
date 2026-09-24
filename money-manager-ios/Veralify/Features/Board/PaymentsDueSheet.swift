import SwiftUI
import SwiftData
import VeralifyCore

/// This month's payments, as a checklist.
///
/// The board's to-do bubble opens here. Each debt not yet paid this month is a
/// row you tick when you have paid it; ticking records the instalment against
/// the debt, the same as the payment sheet does, so the balance and the plan
/// both move. When the last one is ticked the bubble is gone.
struct PaymentsDueSheet: View {
    let debts: [DebtRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        // Scrolls so a long list of debts, or a large type size, runs on
        // rather than clipping the rows at the foot of the sheet.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Still to pay")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tick a payment once you have made it this month.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }

                if debts.isEmpty {
                    Text("Everything for this month is paid.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                } else {
                    GroupedCard {
                        ForEach(Array(debts.enumerated()), id: \.element.remoteID) { index, debt in
                            if index > 0 { RowDivider() }
                            row(debt)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .presentationDragIndicator(.visible)
    }

    private func row(_ debt: DebtRecord) -> some View {
        Button {
            markPaid(debt)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Due this month")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 8)

                // The figure keeps its width; a long name wraps instead.
                Text(CurrencyFormat.string(debt.monthlyPayment))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
            }
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
    }

    /// Records this month's instalment. The split matches the amortization the
    /// engine assumes: interest is a month of the rate on the balance, and the
    /// rest comes off the principal.
    private func markPaid(_ debt: DebtRecord) {
        let monthlyInterest = debt.balance * debt.apr / 100 / 12
        let interest = min(max(monthlyInterest, 0), debt.monthlyPayment)
        let principal = min(debt.monthlyPayment - interest, debt.balance)

        let payment = DebtPayment(
            debtRemoteID: debt.remoteID,
            amount: principal,
            interestPortion: interest,
            date: .now,
            isPaid: true
        )
        context.insert(payment)
        debt.applyPayment(payment)
        try? context.save()

        // Close once the list is emptied, so the sheet does not sit open on
        // "Everything is paid".
        if debts.allSatisfy({ $0.remoteID == debt.remoteID || isPaidThisMonth($0) }) {
            dismiss()
        }
    }

    private func isPaidThisMonth(_ debt: DebtRecord) -> Bool {
        // The caller only passes unpaid debts, so any other row is still due.
        false
    }
}
