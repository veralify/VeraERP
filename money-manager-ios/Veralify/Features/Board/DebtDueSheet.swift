import Foundation
import SwiftUI
import SwiftData
import VeralifyCore

/// What one debt needs this month, opened by tapping its bubble.
///
/// The board answers "how big is this" at a glance; this answers "what do I
/// owe on it right now" — the instalment split into interest and principal,
/// and a single action to mark it paid (or undo that).
struct DebtDueSheet: View {
    let debt: DebtRecord
    let paidThisMonth: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private var monthlyInterest: Decimal {
        min(max(debt.balance * debt.apr / 100 / 12, 0), debt.monthlyPayment)
    }
    private var principal: Decimal { min(debt.monthlyPayment - monthlyInterest, debt.balance) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(paidThisMonth ? "Paid this month" : "Due this month")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(paidThisMonth ? Theme.lime : Theme.textTertiary)
            }

            Text(CurrencyFormat.string(debt.monthlyPayment))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            GroupedCard {
                row("Comes off the balance", CurrencyFormat.string(principal), tint: Theme.green)
                RowDivider()
                row("Interest this month", CurrencyFormat.string(monthlyInterest), tint: Theme.red)
                RowDivider()
                row("Still owed after", CurrencyFormat.string(max(debt.balance - principal, 0)), tint: Theme.textPrimary)
            }

            Spacer(minLength: 0)

            if paidThisMonth {
                Button(role: .destructive) { undo() } label: {
                    Text("Mark as not paid")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.surfaceElevated, in: .capsule)
                        .foregroundStyle(Theme.red)
                }
                .buttonStyle(.pressable)
            } else {
                SwipeToConfirm(title: "Swipe to mark paid", accent: Theme.lime) {
                    markPaid()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background)
        .presentationDragIndicator(.visible)
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

    private func markPaid() {
        let payment = DebtPayment(
            debtRemoteID: debt.remoteID,
            amount: principal,
            interestPortion: monthlyInterest,
            date: .now,
            isPaid: true
        )
        context.insert(payment)
        debt.applyPayment(payment)
        try? context.save()
        dismiss()
    }

    /// Reverses the most recent paid instalment recorded this month.
    private func undo() {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<DebtPayment>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let payment = (try? context.fetch(descriptor))?.first(where: {
            $0.debtRemoteID == debt.remoteID && $0.isPaid
                && calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
        }) else { dismiss(); return }

        debt.reversePayment(payment)
        context.delete(payment)
        try? context.save()
        dismiss()
    }
}
