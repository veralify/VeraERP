import SwiftUI
import SwiftData

/// One form for both adding and editing, so the two paths cannot drift apart in
/// validation or appearance.
struct EntryFormSheet: View {
    enum Mode {
        /// Adding. A nil kind lets the user pick — that is the dock's entry point.
        case add(EntryKind?)
        case edit(EditTarget)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]

    private let mode: Mode
    /// Fixed when editing or when the caller chose a kind; otherwise pickable.
    private let kindIsFixed: Bool

    @State private var kind: EntryKind
    @State private var name: String
    @State private var amount: String
    @State private var apr: String
    @State private var minimum: String
    @State private var dueDay: String
    @State private var isConfirmingDelete = false
    @FocusState private var isEditingField: Bool

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add(let kind):
            kindIsFixed = kind != nil
            _kind = State(initialValue: kind ?? .income)
            _name = State(initialValue: "")
            _amount = State(initialValue: "")
            _apr = State(initialValue: "")
            _minimum = State(initialValue: "")
            _dueDay = State(initialValue: "")

        case .edit(let target):
            kindIsFixed = true
            _kind = State(initialValue: target.kind)
            switch target {
            case .income(let item):
                _name = State(initialValue: item.name)
                _amount = State(initialValue: item.amount.editableText)
                _apr = State(initialValue: "")
                _minimum = State(initialValue: "")
                _dueDay = State(initialValue: "")
            case .expense(let item):
                _name = State(initialValue: item.name)
                _amount = State(initialValue: item.amount.editableText)
                _apr = State(initialValue: "")
                _minimum = State(initialValue: "")
                _dueDay = State(initialValue: item.dueDay.map(String.init) ?? "")
            case .debt(let item):
                _name = State(initialValue: item.name)
                _amount = State(initialValue: item.balance.editableText)
                _apr = State(initialValue: item.apr.editableText)
                _minimum = State(initialValue: item.minimumPayment.editableText)
                _dueDay = State(initialValue: item.dueDay.map(String.init) ?? "")
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let value = AmountParser.parse(amount), value > 0
        else { return false }
        if kind == .debt { return AmountParser.parse(minimum) != nil }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if !kindIsFixed {
                            Picker("Type", selection: $kind) {
                                ForEach(EntryKind.allCases) { option in
                                    Text(option.shortTitle).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 12) {
                            FieldRow(label: "Name", placeholder: "Name", text: $name, focus: $isEditingField)
                            FieldRow(
                                label: kind.amountLabel,
                                placeholder: "0.00",
                                text: $amount,
                                keyboard: .decimalPad,
                                focus: $isEditingField
                            )
                            if kind == .debt {
                                HStack(spacing: 12) {
                                    FieldRow(label: "Annual interest %", placeholder: "0", text: $apr, keyboard: .decimalPad)
                                    FieldRow(label: "Minimum", placeholder: "0.00", text: $minimum, keyboard: .decimalPad)
                                }
                            }
                            // Income has no due date; the other two drive alerts.
                            if kind != .income {
                                FieldRow(
                                    label: "Due day (optional)",
                                    placeholder: "1–31",
                                    text: $dueDay,
                                    keyboard: .numberPad
                                )
                            }
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        PrimaryButton(title: "Save", enabled: canSave, action: save)

                        if isEditing {
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Text("Delete")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(Theme.red.opacity(0.13), in: .capsule)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard(focus: $isEditingField)
            }
            .navigationTitle(isEditing ? "Edit" : "Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog("Delete this item?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard canSave, let value = AmountParser.parse(amount) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let day = DayParser.parse(dueDay)

        switch mode {
        case .add:
            switch kind {
            case .income:
                context.insert(IncomeSource(name: trimmed, amount: value))
            case .expense:
                context.insert(ExpenseItem(name: trimmed, amount: value, dueDay: day))
            case .debt:
                // Debt ids drive the engine's minimum-payment ordering, so a new
                // debt takes the next id rather than reusing a gap.
                let nextID = (debts.map(\.remoteID).max() ?? 0) + 1
                context.insert(
                    DebtRecord(
                        remoteID: nextID,
                        name: trimmed,
                        balance: value,
                        apr: AmountParser.parse(apr) ?? 0,
                        minimumPayment: AmountParser.parse(minimum) ?? 0,
                        dueDay: day,
                        priority: nextID
                    )
                )
            }

        case .edit(let target):
            switch target {
            case .income(let item):
                item.name = trimmed
                item.amount = value
            case .expense(let item):
                item.name = trimmed
                item.amount = value
                item.dueDay = day
            case .debt(let item):
                item.name = trimmed
                item.balance = value
                item.apr = AmountParser.parse(apr) ?? 0
                item.minimumPayment = AmountParser.parse(minimum) ?? 0
                item.dueDay = day
            }
        }

        try? context.save()
        dismiss()
    }

    private func delete() {
        guard case .edit(let target) = mode else { return }
        switch target {
        case .income(let item):  context.delete(item)
        case .expense(let item): context.delete(item)
        case .debt(let item):    context.delete(item)
        }
        try? context.save()
        dismiss()
    }
}

extension Decimal {
    /// Plain text for a form field: no grouping separators, and no trailing
    /// ".00" for whole amounts, so an edited value is not fiddly to retype.
    var editableText: String {
        let number = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "\(number)"
    }
}
