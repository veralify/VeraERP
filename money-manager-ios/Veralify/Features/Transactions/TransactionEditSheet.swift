import SwiftUI
import SwiftData

/// Edit or delete a recorded entry.
struct TransactionEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let record: TransactionRecord

    @State private var name: String
    @State private var amount: String
    @State private var direction: EntryDirection
    @State private var scope: EntryScope
    @State private var category: String
    @State private var account: String
    @State private var date: Date
    @State private var isConfirmingDelete = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Bottom-aligned when side by side, so a label that wraps to two lines
    /// does not knock its menu out of line with its neighbour.
    private var pairLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
    }

    init(record: TransactionRecord) {
        self.record = record
        _name = State(initialValue: record.name)
        _amount = State(initialValue: record.amount.editableText)
        _direction = State(initialValue: record.direction)
        _scope = State(initialValue: record.scope)
        _category = State(initialValue: record.category)
        _account = State(initialValue: record.account)
        _date = State(initialValue: record.occurredAt)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (AmountParser.parse(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Type", selection: $direction) {
                            ForEach(EntryDirection.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Picker("Scope", selection: $scope) {
                            ForEach(EntryScope.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 12) {
                            FieldRow(label: "Name", placeholder: "Name", text: $name)
                            FieldRow(label: "Amount", placeholder: "0.00", text: $amount, keyboard: .decimalPad)

                            // Side by side normally; stacked at accessibility
                            // sizes, where two menus in half the width each
                            // cut their values to a letter or two.
                            pairLayout {
                                pickerRow("Category", $category, EntryPresets.categories)
                                pickerRow("Account", $account, EntryPresets.accounts)
                            }

                            DateField(label: "Date", date: $date)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        PrimaryButton(title: "Save", enabled: canSave, action: save)

                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Text("Delete")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Theme.red.opacity(0.13), in: .capsule)
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog("Delete this entry?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    context.delete(record)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func pickerRow(_ label: LocalizedStringKey, _ value: Binding<String>, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { value.wrappedValue = option }
                }
            } label: {
                HStack {
                    Text(value.wrappedValue)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.inner).strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
    }

    private func save() {
        guard canSave, let value = AmountParser.parse(amount) else { return }
        record.name = name.trimmingCharacters(in: .whitespaces)
        record.amount = value
        record.direction = direction
        record.scope = scope
        record.category = category
        record.account = account
        record.occurredAt = date
        try? context.save()
        dismiss()
    }
}
