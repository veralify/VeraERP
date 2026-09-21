import SwiftUI
import SwiftData
import VeralifyCore

/// Record a payment against one debt, and see what has been paid so far.
///
/// Two shapes of payment, because they do different things to the loan:
///
/// - **Payment** — a scheduled instalment, or more than one. Reduces the
///   balance and leaves the monthly figure alone.
/// - **Early payoff** — a lump sum off the capital ahead of schedule. The
///   lender splits it into capital and accrued interest, takes only the capital
///   off the debt, and re-amortises the rest over the term that is left, which
///   lowers the monthly instalment. That recalculation is the whole reason
///   anyone does this, so the sheet shows it before it is committed.
struct DebtPaymentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var payments: [DebtPayment]

    let debt: DebtRecord

    enum Mode: Int, CaseIterable, Identifiable {
        case payment, earlyPayoff
        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .payment: "Payment"
            case .earlyPayoff: "Early payoff"
            }
        }
    }

    @State private var mode: Mode = .payment
    @State private var amount: String
    @State private var interest: String = ""
    @State private var newMinimum: String = ""
    @State private var lowersInstalment = true
    @State private var date: Date
    @State private var isPaid: Bool
    @State private var hasEditedPaidFlag = false
    @State private var hasEditedNewMinimum = false

    init(debt: DebtRecord) {
        self.debt = debt
        _amount = State(initialValue: debt.minimumPayment.editableText)
        // Default to this month's due day when there is one, so the common case
        // is one tap.
        let suggested = debt.dueDay.flatMap {
            BillSchedule.nextOccurrence(dueDay: $0, from: .now, calendar: .current)
        }
        let start = suggested ?? .now
        _date = State(initialValue: start)
        _isPaid = State(initialValue: Calendar.current.startOfDay(for: start) <= Calendar.current.startOfDay(for: .now))
    }

    // MARK: - Derived values

    private var parsedAmount: Decimal? { AmountParser.parse(amount) }
    private var parsedInterest: Decimal { AmountParser.parse(interest) ?? 0 }
    private var canRecord: Bool { (parsedAmount ?? 0) > 0 }

    private var monthlyRate: Decimal { Money.monthlyRate(apr: debt.apr) }

    /// What the balance becomes once this payment is applied. A planned payment
    /// has not moved the balance yet, so the caption under the figure says when
    /// it will — the preview is worth showing either way.
    private var projectedBalance: Decimal {
        guard let value = parsedAmount, value > 0 else { return debt.balance }
        return max(0, debt.balance - value)
    }

    /// Payments left at the current instalment, derived rather than stored:
    /// balance, rate and instalment already determine the term.
    private var remainingMonths: Int? {
        LoanMath.remainingMonths(
            balance: debt.balance,
            monthlyRate: monthlyRate,
            instalment: debt.minimumPayment
        )
    }

    /// What the lender would re-amortise the remaining capital to.
    ///
    /// Only once capital has actually been entered. The remaining term is a
    /// whole number of payments, so re-amortising an unchanged balance over it
    /// shaves a little off the instalment — an artefact of that rounding, not a
    /// saving, and not something to show as one.
    private var suggestedInstalment: Decimal? {
        guard mode == .earlyPayoff,
              let repaid = parsedAmount, repaid > 0,
              projectedBalance > 0,
              let months = remainingMonths
        else { return nil }
        return LoanMath.instalment(
            principal: projectedBalance,
            monthlyRate: monthlyRate,
            months: months
        )
    }

    /// The instalment that will actually be written, once the user has had a
    /// chance to correct it from the lender's letter.
    private var appliedInstalment: Decimal? {
        guard mode == .earlyPayoff, lowersInstalment else { return nil }
        guard let typed = AmountParser.parse(newMinimum), typed > 0 else { return suggestedInstalment }
        return typed
    }

    private var history: [DebtPayment] {
        payments
            .filter { $0.debtRemoteID == debt.remoteID }
            .sorted { $0.date > $1.date }
    }

    /// Cash out of the account, which includes interest that never touched the
    /// balance.
    private var totalPaid: Decimal {
        history.filter(\.isPaid).reduce(0) { $0 + $1.totalCharged }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        balanceCard
                        modePicker
                        form
                        if mode == .earlyPayoff { instalmentCard }
                        PrimaryButton(title: "Record payment", enabled: canRecord, action: record)
                        if !history.isEmpty { historySection }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle(LocalizedStringKey(debt.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remaining balance")
                .font(.caption.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(Theme.onAccent.opacity(0.7))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CurrencyFormat.string(debt.balance))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Shows the effect before it is committed, so a mistyped amount
                // is obvious before it touches the balance.
                if projectedBalance != debt.balance {
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                    Text(CurrencyFormat.string(projectedBalance))
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(Theme.onAccent)

            if projectedBalance != debt.balance {
                Text(isPaid ? "After this payment" : "Once you mark it paid")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.7))
            }

            if let instalment = appliedInstalment, instalment != debt.minimumPayment {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2.weight(.bold))
                    Text("Monthly \(CurrencyFormat.string(debt.minimumPayment)) → \(CurrencyFormat.string(instalment))")
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.onAccent.opacity(0.12), in: .capsule)
            }

            if totalPaid > 0 {
                Text("\(CurrencyFormat.string(totalPaid)) paid so far")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.75))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
        .animation(reduceMotion ? .none : .snappy(duration: 0.28), value: projectedBalance)
        .animation(reduceMotion ? .none : .snappy(duration: 0.28), value: isPaid)
        .animation(reduceMotion ? .none : .snappy(duration: 0.28), value: appliedInstalment)
        .accessibilityElement(children: .combine)
    }

    private var modePicker: some View {
        Picker("Kind", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, newValue in
            // Each mode wants a different starting amount: an instalment for a
            // scheduled payment, nothing prefilled for a lump sum the user is
            // copying off a letter.
            amount = newValue == .payment ? debt.minimumPayment.editableText : ""
            interest = ""
            hasEditedNewMinimum = false
            newMinimum = ""
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            FieldRow(
                label: mode == .earlyPayoff ? "Capital repaid" : "Amount",
                placeholder: "0.00",
                text: $amount,
                keyboard: .decimalPad
            )

            if mode == .earlyPayoff {
                FieldRow(
                    label: "Interest and fees",
                    placeholder: "0.00",
                    text: $interest,
                    keyboard: .decimalPad
                )

                if parsedInterest > 0, let principal = parsedAmount {
                    Text("\(CurrencyFormat.string(principal + parsedInterest)) charged, of which \(CurrencyFormat.string(principal)) comes off the debt.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.label) { option in
                        Button {
                            amount = option.value.editableText
                        } label: {
                            Text(option.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Theme.surfaceElevated, in: .capsule)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }

            DateField(label: "Date", date: $date)
                .onChange(of: date) { _, newValue in
                    // Follow the date unless the user has overridden it.
                    guard !hasEditedPaidFlag else { return }
                    isPaid = Calendar.current.startOfDay(for: newValue) <= Calendar.current.startOfDay(for: .now)
                }

            Toggle(isOn: $isPaid) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Already paid")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(isPaid
                         ? "Reduces the balance now."
                         : "Planned — the balance changes when you mark it paid.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .tint(Theme.lime)
            .onChange(of: isPaid) { _, _ in hasEditedPaidFlag = true }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    /// The re-amortisation. Editable, because the lender's letter is the
    /// authority — its rounding and day-count conventions are its own, and this
    /// figure is only ever within a cent or so of them.
    private var instalmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $lowersInstalment) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lower the monthly payment")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(lowersInstalment
                         ? "Spread what is left over the same remaining term."
                         : "Keep paying the same each month and finish sooner.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.lime)

            if lowersInstalment {
                if suggestedInstalment != nil {
                    FieldRow(
                        label: "New monthly payment",
                        placeholder: "0.00",
                        text: $newMinimum,
                        keyboard: .decimalPad
                    )

                    if let months = remainingMonths {
                        Text("Worked out over the \(months) payments you have left. If your lender's letter says otherwise, use their figure.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if (parsedAmount ?? 0) > 0 {
                    // Only once there is something to work from: before that,
                    // silence is not a problem report.
                    Text("There isn't enough information to work out a new monthly payment — the debt needs an interest rate and a monthly payment that covers it.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        // Keep the suggestion in step with the amount until the user takes it
        // over; after that it is theirs.
        .onChange(of: suggestedInstalment) { _, newValue in
            guard !hasEditedNewMinimum else { return }
            newMinimum = newValue?.editableText ?? ""
        }
        .onChange(of: newMinimum) { _, newValue in
            guard newValue != suggestedInstalment?.editableText else { return }
            hasEditedNewMinimum = true
        }
    }

    /// The minimum, a round step above it, and clearing the debt outright.
    private var quickAmounts: [(label: String, value: Decimal)] {
        var options: [(String, Decimal)] = []
        if debt.minimumPayment > 0 {
            options.append((String(localized: "Minimum"), debt.minimumPayment))
            options.append((CurrencyFormat.string(debt.minimumPayment * 2), debt.minimumPayment * 2))
        }
        if debt.balance > 0 {
            options.append((String(localized: "Pay off"), debt.balance))
        }
        return options
    }

    private var historySection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Payments") {
                Text("\(history.count)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            GroupedCard {
                ForEach(Array(history.enumerated()), id: \.element.persistentModelID) { index, payment in
                    if index > 0 { RowDivider() }
                    paymentRow(payment)
                }
            }
        }
    }

    private func paymentRow(_ payment: DebtPayment) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(payment.isPaid ? Theme.green : Theme.blue)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyFormat.string(payment.totalCharged))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(payment.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if payment.isEarlyPayoff {
                    Text(payment.interestPortion > 0
                         ? "Early payoff · \(CurrencyFormat.string(payment.interestPortion)) interest"
                         : "Early payoff")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer(minLength: 8)

            if payment.isPaid {
                Pill(text: String(localized: "Paid"), style: .muted(dot: Theme.green))
            } else {
                Button {
                    markPaid(payment)
                } label: {
                    Text("Mark paid")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.lime, in: .capsule)
                }
                .buttonStyle(.pressable)
            }

            // An explicit control rather than a hidden long-press: correcting a
            // mistyped payment is the reason the ledger exists, and a gesture
            // nothing advertises is not a way to offer it.
            Menu {
                rowActions(payment)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More")
        }
        .padding(.vertical, 12)
        .contextMenu { rowActions(payment) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func rowActions(_ payment: DebtPayment) -> some View {
        if payment.isPaid {
            Button {
                markUnpaid(payment)
            } label: {
                Label("Mark as not paid", systemImage: "arrow.uturn.backward")
            }
        }
        Button(role: .destructive) { delete(payment) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func record() {
        guard let value = parsedAmount, value > 0 else { return }
        let isEarly = mode == .earlyPayoff
        let instalment = appliedInstalment
        let payment = DebtPayment(
            debtRemoteID: debt.remoteID,
            amount: value,
            interestPortion: isEarly ? parsedInterest : 0,
            date: date,
            isPaid: isPaid,
            isEarlyPayoff: isEarly,
            previousMinimum: instalment == nil ? nil : debt.minimumPayment,
            newMinimum: instalment
        )
        context.insert(payment)
        if isPaid { debt.applyPayment(payment) }
        try? context.save()
        dismiss()
    }

    private func markPaid(_ payment: DebtPayment) {
        guard !payment.isPaid else { return }
        payment.isPaid = true
        debt.applyPayment(payment)
        try? context.save()
    }

    /// Undo a mark-paid without losing the record — the payment goes back to
    /// being planned and the balance goes back with it.
    private func markUnpaid(_ payment: DebtPayment) {
        guard payment.isPaid else { return }
        debt.reversePayment(payment)
        payment.isPaid = false
        try? context.save()
    }

    private func delete(_ payment: DebtPayment) {
        // Deleting a payment that was applied has to give the money back, or
        // the balance quietly drifts away from the ledger.
        if payment.isPaid { debt.reversePayment(payment) }
        context.delete(payment)
        try? context.save()
    }
}
