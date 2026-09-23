import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for one debt. Carries the id rather than the model object,
/// so the destination re-reads a live record instead of holding a stale one.
struct DebtRoute: Hashable {
    let remoteID: Int
}

/// One debt in full: how far through it you are, and every payment made
/// against it.
///
/// Progress is measured from what has actually been paid through the app, not
/// from an original loan amount — the app never knew that figure. So a debt
/// with no recorded payments reads 0%, which is honest: nothing has been
/// tracked yet, whatever was paid before.
struct DebtDetailView: View {
    let remoteID: Int

    @Environment(\.modelContext) private var context
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query(sort: \DebtPayment.date, order: .reverse) private var allPayments: [DebtPayment]

    @State private var isPaying = false
    @State private var isEditing = false

    private var debt: DebtRecord? { debts.first { $0.remoteID == remoteID } }

    private var payments: [DebtPayment] {
        allPayments.filter { $0.debtRemoteID == remoteID }
    }

    /// Instalments left at the current monthly figure.
    private var paymentsLeft: Int? {
        guard let debt else { return nil }
        return LoanMath.remainingMonths(
            balance: debt.balance,
            monthlyRate: Money.monthlyRate(apr: debt.apr),
            instalment: debt.minimumPayment
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let debt {
                ScrollView {
                    VStack(spacing: 18) {
                        hero(debt)
                        statStrip(debt)
                        paymentsSection(debt)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 108)
                }
                .scrollIndicators(.hidden)
            } else {
                // The debt was deleted while this screen was open.
                EmptyStateView(
                    icon: "creditcard",
                    title: "This debt is gone",
                    message: "It was deleted. Go back to see the ones you still have."
                )
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle(debt.map { LocalizedStringKey($0.name) } ?? "Debt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let debt {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                        .accessibilityLabel("Edit \(debt.name)")
                }
            }
        }
        .sheet(isPresented: $isPaying) {
            if let debt {
                DebtPaymentSheet(debt: debt).presentationBackground(Theme.background)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let debt {
                EntryFormSheet(mode: .edit(.debt(debt))).presentationBackground(Theme.background)
            }
        }
    }

    // MARK: - Hero

    private func hero(_ debt: DebtRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(debt.name))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(debt.apr > 0
                     ? "\(debt.apr.percentText)% interest"
                     : "No interest")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.7))
            }

            let progress = DebtProgress(debt: debt, payments: allPayments)

            ProgressTrack(progress: progress.fraction)

            HStack(spacing: 10) {
                Text("\(CurrencyFormat.string(progress.paid)) of \(CurrencyFormat.string(progress.starting))")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                Text("\(progress.percent)% paid")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.white, in: .capsule)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.onAccent.opacity(0.12), in: .capsule)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Figures

    private func statStrip(_ debt: DebtRecord) -> some View {
        HStack(spacing: 10) {
            statTile("Remaining", CurrencyFormat.string(debt.balance))
            statTile("Monthly", CurrencyFormat.string(debt.monthlyPayment))
            if let paymentsLeft {
                statTile("Left", String(localized: "\(paymentsLeft) payments"))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statTile(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Payments

    private func paymentsSection(_ debt: DebtRecord) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Payments: \(payments.count)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Button { isPaying = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.lime)
                }
                .buttonStyle(.pressable)
            }

            if payments.isEmpty {
                VStack(spacing: 14) {
                    Text("No payments recorded yet. Add one and this debt starts showing its progress.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PrimaryButton(title: "Record a payment", enabled: true) { isPaying = true }
                }
                .padding(16)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            } else {
                VStack(spacing: 12) {
                    ForEach(payments) { payment in
                        paymentCard(payment, debt: debt)
                    }
                }
            }
        }
    }

    private func paymentCard(_ payment: DebtPayment, debt: DebtRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(CurrencyFormat.string(payment.totalCharged))
                    .font(.system(size: 21, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(payment.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(description(for: payment))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Pill(
                    text: payment.isPaid ? String(localized: "Paid") : String(localized: "Planned"),
                    style: .muted(dot: payment.isPaid ? Theme.green : Theme.blue)
                )
                Pill(
                    text: payment.isEarlyPayoff
                        ? String(localized: "Early payoff")
                        : String(localized: "Payment"),
                    style: .accent(payment.isEarlyPayoff ? Theme.yellow : Theme.green)
                )
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .contextMenu {
            if !payment.isPaid {
                Button {
                    payment.isPaid = true
                    debt.applyPayment(payment)
                    try? context.save()
                } label: {
                    Label("Mark paid", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive) {
                if payment.isPaid { debt.reversePayment(payment) }
                context.delete(payment)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func description(for payment: DebtPayment) -> String {
        if payment.isEarlyPayoff, payment.interestPortion > 0 {
            return String(
                localized: "\(CurrencyFormat.string(payment.amount)) off the balance, \(CurrencyFormat.string(payment.interestPortion)) interest."
            )
        }
        if payment.isEarlyPayoff {
            return String(localized: "Paid ahead of schedule, straight off the balance.")
        }
        return String(localized: "A scheduled payment against this debt.")
    }
}
