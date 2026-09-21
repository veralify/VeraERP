import SwiftUI
import SwiftData

/// All records of one kind: tap to edit, swipe to delete, plus to add.
struct EntryListView: View {
    let kind: EntryKind

    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]

    @State private var editing: EditTarget?
    @State private var isAdding = false
    @State private var payingDebt: DebtRecord?

    private var targets: [EditTarget] {
        switch kind {
        case .income:  income.map(EditTarget.income)
        case .expense: expenses.map(EditTarget.expense)
        case .debt:    debts.map(EditTarget.debt)
        }
    }

    private var total: Decimal {
        switch kind {
        case .income:  income.filter(\.isActive).reduce(0) { $0 + $1.amount }
        case .expense: expenses.filter(\.isActive).reduce(0) { $0 + $1.amount }
        case .debt:    debts.reduce(0) { $0 + $1.balance }
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if targets.isEmpty {
                EmptyStateView(
                    icon: kind.emptyIcon,
                    title: "Nothing here yet",
                    message: kind.emptyMessage
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        totalCard

                        GroupedCard {
                            ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                                if index > 0 { RowDivider() }
                                row(for: target)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(kind.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.lime)
                }
                .accessibilityLabel("Add")
            }
        }
        .sheet(item: $editing) { target in
            EntryFormSheet(mode: .edit(target))
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $isAdding) {
            EntryFormSheet(mode: .add(kind))
                .presentationBackground(Theme.background)
        }
        .sheet(item: $payingDebt) { debt in
            DebtPaymentSheet(debt: debt)
                .presentationBackground(Theme.background)
        }
    }

    private var totalCard: some View {
        HStack {
            Text(kind == .debt ? "Total balance" : "Monthly total")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(CurrencyFormat.string(total))
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(kind.accent)
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func row(for target: EditTarget) -> some View {
        // The row and the Pay action are siblings, not nested: a Button inside
        // another Button's label does not reliably receive taps, and an overlay
        // would sit on top of the balance.
        VStack(alignment: .leading, spacing: 0) {
            Button {
                editing = target
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title(for: target))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let detail = detail(for: target) {
                            Text(detail)
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(CurrencyFormat.string(amount(for: target)))
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 15)
                .contentShape(.rect)
            }
            .buttonStyle(.pressableRow)
            .accessibilityHint("Open to edit")

            if case .debt(let item) = target {
                Button { payingDebt = item } label: {
                    Label("Record payment", systemImage: "creditcard")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.lime, in: .capsule)
                }
                .buttonStyle(.pressable)
                .padding(.bottom, 14)
            }
        }
        .contextMenu {
            if case .debt(let item) = target {
                Button { payingDebt = item } label: {
                    Label("Record payment", systemImage: "creditcard")
                }
            }
            Button(role: .destructive) {
                delete(target)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Row content

    private func title(for target: EditTarget) -> String {
        switch target {
        case .income(let item):  item.name
        case .expense(let item): item.name
        case .debt(let item):    item.name
        }
    }

    private func amount(for target: EditTarget) -> Decimal {
        switch target {
        case .income(let item):  item.amount
        case .expense(let item): item.amount
        case .debt(let item):    item.balance
        }
    }

    private func detail(for target: EditTarget) -> String? {
        switch target {
        case .income:
            return nil
        case .expense(let item):
            return item.dueDay.map { String(localized: "Due on day \($0)") }
        case .debt(let item):
            var parts = [String(localized: "Minimum \(CurrencyFormat.string(item.minimumPayment))")]
            if item.apr > 0 { parts.append(String(localized: "\(item.apr.percentText)% interest")) }
            if let day = item.dueDay { parts.append(String(localized: "day \(day)")) }
            return parts.joined(separator: " · ")
        }
    }

    private func delete(_ target: EditTarget) {
        switch target {
        case .income(let item):  context.delete(item)
        case .expense(let item): context.delete(item)
        case .debt(let item):    context.delete(item)
        }
        try? context.save()
    }
}
