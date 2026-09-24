import SwiftUI

/// A step that collects a list of name + amount entries (income, expenses).
struct EntryStep: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let namePlaceholder: LocalizedStringKey
    let accent: Color
    @Binding var entries: [DraftEntry]
    let primaryTitle: LocalizedStringKey
    let onContinue: () -> Void

    @State private var name = ""
    @State private var amount = ""

    private var parsedAmount: Decimal? { AmountParser.parse(amount) }
    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        OnboardingScaffold(title: title, subtitle: subtitle) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    FieldRow(label: "Name", placeholder: namePlaceholder, text: $name, submitLabel: .next)
                    FieldRow(label: "Monthly amount", placeholder: "0.00", text: $amount, keyboard: .decimalPad)

                    Button(action: add) {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(canAdd ? accent : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.surfaceElevated, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                    .disabled(!canAdd)
                }
                .padding(16)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                if !entries.isEmpty {
                    GroupedCard {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { RowDivider() }
                            EntryChipRow(
                                title: entry.name,
                                detail: CurrencyFormat.string(entry.amount),
                                accent: accent
                            ) {
                                entries.removeAll { $0.id == entry.id }
                            }
                        }
                    }

                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(CurrencyFormat.string(entries.reduce(0) { $0 + $1.amount }))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal, 4)
                }
            }
        } actions: {
            PrimaryButton(title: primaryTitle, action: onContinue)
        }
    }

    private func add() {
        guard let value = parsedAmount, canAdd else { return }
        entries.append(DraftEntry(name: name.trimmingCharacters(in: .whitespaces), amount: value))
        name = ""
        amount = ""
    }
}

/// Debts need more than a name and an amount, so they get their own step.
struct DebtStep: View {
    @Binding var debts: [DraftDebt]
    let onContinue: () -> Void

    @State private var name = ""
    @State private var balance = ""
    @State private var apr = ""
    @State private var minimum = ""
    @State private var dueDay = ""

    private var canAdd: Bool {
        // Optional fields may stay empty, but a typed value that does not parse
        // must not be quietly dropped (a due day of "45", a rate of "abc").
        let dueDayIsValid = dueDay.trimmingCharacters(in: .whitespaces).isEmpty
            || DayParser.parse(dueDay) != nil
        let aprIsValid = apr.trimmingCharacters(in: .whitespaces).isEmpty
            || AmountParser.parse(apr) != nil
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (AmountParser.parse(balance) ?? 0) > 0
            && AmountParser.parse(minimum) != nil
            && dueDayIsValid
            && aprIsValid
    }

    var body: some View {
        OnboardingScaffold(
            title: "Which debts are you paying off?",
            subtitle: "The balance left and the minimum payment. If you don't know the interest rate, leave it at zero."
        ) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    FieldRow(label: "Debt name", placeholder: "e.g. Credit card", text: $name, submitLabel: .next)
                    FieldRow(label: "Remaining balance", placeholder: "0.00", text: $balance, keyboard: .decimalPad)
                    HStack(spacing: 12) {
                        FieldRow(label: "Annual interest %", placeholder: "0", text: $apr, keyboard: .decimalPad)
                        FieldRow(label: "Minimum", placeholder: "0.00", text: $minimum, keyboard: .decimalPad)
                    }
                    FieldRow(label: "Due day (optional)", placeholder: "1–31", text: $dueDay, keyboard: .numberPad)

                    Button(action: add) {
                        Label("Add debt", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(canAdd ? Theme.red : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.surfaceElevated, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                    .disabled(!canAdd)
                }
                .padding(16)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                if !debts.isEmpty {
                    GroupedCard {
                        ForEach(Array(debts.enumerated()), id: \.element.id) { index, debt in
                            if index > 0 { RowDivider() }
                            EntryChipRow(
                                title: debt.name,
                                detail: "\(CurrencyFormat.string(debt.balance)) · \(debt.apr.percentText)% · \(CurrencyFormat.string(debt.minimumPayment))",
                                accent: debt.apr > 0 ? Theme.red : Theme.blue
                            ) {
                                debts.removeAll { $0.id == debt.id }
                            }
                        }
                    }
                }
            }
        } actions: {
            PrimaryButton(title: debts.isEmpty ? "I have no debts" : "Continue", action: onContinue)
        }
    }

    private func add() {
        guard canAdd,
              let balanceValue = AmountParser.parse(balance),
              let minimumValue = AmountParser.parse(minimum)
        else { return }

        debts.append(
            DraftDebt(
                name: name.trimmingCharacters(in: .whitespaces),
                balance: balanceValue,
                apr: AmountParser.parse(apr) ?? 0,
                minimumPayment: minimumValue,
                dueDay: DayParser.parse(dueDay)
            )
        )
        name = ""
        balance = ""
        apr = ""
        minimum = ""
        dueDay = ""
    }
}
