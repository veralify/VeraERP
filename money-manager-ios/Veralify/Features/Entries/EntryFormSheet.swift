import SwiftUI
import SwiftData
import VeralifyCore

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
    @State private var incomeKind: IncomeKind = .fixed
    @State private var isConfirmingDelete = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Bottom-aligned when side by side: "Annual interest %" can wrap to two
    /// lines in half the width, and top alignment then left its field lower
    /// than the one beside it. Stacked at accessibility sizes.
    private var pairLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
    }

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
                _incomeKind = State(initialValue: item.incomeKind)
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
        // A cleared debt is edited at a zero balance (to rename it, say); a new
        // entry of nothing is not worth adding.
        let allowsZero = isEditing && kind == .debt
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let value = AmountParser.parse(amount), value > 0 || (allowsZero && value == 0)
        else { return false }
        // Optional fields may be left empty, but a typed value that does not
        // parse must stop the save. Otherwise "45" silently cleared the due day
        // (and with it every alert), and a mistyped rate became 0%.
        if kind != .income, !dueDay.trimmingCharacters(in: .whitespaces).isEmpty,
           DayParser.parse(dueDay) == nil { return false }
        if kind == .debt {
            if !apr.trimmingCharacters(in: .whitespaces).isEmpty, AmountParser.parse(apr) == nil {
                return false
            }
            return AmountParser.parse(minimum) != nil
        }
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
                            FieldRow(label: "Name", placeholder: "Name", text: $name)
                            if kind == .income {
                                incomeKindPicker
                            }
                            FieldRow(
                                label: amountLabel,
                                placeholder: "0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )
                            if kind == .debt {
                                pairLayout {
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
                .dismissibleKeyboard()
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

    /// Variable pay is typed as a typical month; the real figure is logged
    /// each month from the income list.
    private var amountLabel: LocalizedStringKey {
        kind == .income && incomeKind == .variable ? "Typical month" : kind.amountLabel
    }

    private var incomeKindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Income type", selection: $incomeKind) {
                Text("Fixed").tag(IncomeKind.fixed)
                Text("Variable").tag(IncomeKind.variable)
            }
            .pickerStyle(.segmented)
            Text(incomeKind == .fixed
                 ? "The same amount arrives every month."
                 : "It changes month to month. Log what came in each month; the plan uses your recent average.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
                context.insert(IncomeSource(name: trimmed, amount: value, kind: incomeKind.rawValue))
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
                item.incomeKind = incomeKind
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
        case .debt(let item):    context.deleteDebt(item)
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

// MARK: - Variable income: what actually came in

/// Logs what a variable income actually paid in one month.
///
/// One figure per month: saving replaces whatever that month already had, so
/// correcting a typo cannot double-count the month.
struct IncomeActualSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let source: IncomeSource

    @State private var month: Date
    @State private var amount: String

    /// This month and the five before it — enough to catch up after a busy
    /// stretch without offering months nobody remembers.
    private let months: [Date]

    init(source: IncomeSource) {
        self.source = source
        let calendar = Calendar.current
        let current = MonthlySnapshot.monthStart(for: .now, calendar: calendar)
        let months = (0..<6).compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
        self.months = months
        _month = State(initialValue: current)
        _amount = State(initialValue: source.logged(inMonthOf: current)?.editableText ?? "")
    }

    private var parsed: Decimal? { AmountParser.parse(amount) }
    private var isLogged: Bool { source.logged(inMonthOf: month) != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Month", selection: $month) {
                                ForEach(months, id: \.self) { month in
                                    Text(month.formatted(.dateTime.month(.wide).year())).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.lime)

                            FieldRow(
                                label: "Amount received",
                                placeholder: "0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )

                            Text("Typical month: \(CurrencyFormat.string(source.amount))")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        PrimaryButton(title: "Save", enabled: parsed != nil, action: save)

                        if isLogged {
                            Button(role: .destructive, action: remove) {
                                Text("Remove this month")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.red)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle(Text(verbatim: source.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: month) { _, newMonth in
                amount = source.logged(inMonthOf: newMonth)?.editableText ?? ""
            }
        }
    }

    private func entries(in month: Date) -> [IncomeActual] {
        source.actuals.filter { MonthlySnapshot.monthStart(for: $0.month) == month }
    }

    private func save() {
        guard let value = parsed else { return }
        for entry in entries(in: month) { context.delete(entry) }
        context.insert(IncomeActual(month: month, amount: value, source: source))
        try? context.save()
        dismiss()
    }

    private func remove() {
        for entry in entries(in: month) { context.delete(entry) }
        try? context.save()
        dismiss()
    }
}

// MARK: - Money lost

extension LossReason {
    var title: LocalizedStringKey {
        switch self {
        case .lost:       "Lost"
        case .stolen:     "Stolen"
        case .fine:       "Fine"
        case .unexpected: "Unexpected cost"
        case .other:      "Other"
        }
    }

    var icon: String {
        switch self {
        case .lost:       "questionmark.circle"
        case .stolen:     "exclamationmark.shield"
        case .fine:       "doc.text"
        case .unexpected: "bolt"
        case .other:      "ellipsis.circle"
        }
    }
}

/// Records money that left without being planned.
///
/// It comes off what is left for the month it happened in — the Today figure,
/// cash flow and the board all drop by it — and leaves the payoff plan alone.
struct LossSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var reason: LossReason = .lost
    @State private var date = Date()
    @State private var note = ""

    private var parsed: Decimal? { AmountParser.parse(amount) }
    private var canSave: Bool { (parsed ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            FieldRow(label: "Amount lost", placeholder: "0.00", text: $amount, keyboard: .decimalPad)

                            Picker("Reason", selection: $reason) {
                                ForEach(LossReason.allCases) { option in
                                    Label(option.title, systemImage: option.icon).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.lime)

                            DateField(label: "When", date: $date, range: Date.distantPast...Date.now)

                            FieldRow(label: "Note (optional)", placeholder: "What happened", text: $note)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        Text("This comes off what's left for that month. Your payoff plan stays the same.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        PrimaryButton(title: "Save", enabled: canSave, action: save)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Log money lost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func save() {
        guard let value = parsed, value > 0 else { return }
        context.insert(
            MoneyLoss(
                date: date,
                amount: value,
                reason: reason,
                note: note.trimmingCharacters(in: .whitespaces)
            )
        )
        try? context.save()
        dismiss()
    }
}
