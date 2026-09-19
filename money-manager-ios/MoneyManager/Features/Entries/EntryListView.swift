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
                    title: "لا توجد بنود بعد",
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
                .accessibilityLabel("إضافة")
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
    }

    private var totalCard: some View {
        HStack {
            Text(kind == .debt ? "إجمالي الرصيد" : "المجموع الشهري")
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
        .buttonStyle(.plain)
        // `.swipeActions` is a List-only modifier and silently does nothing in a
        // stack, so deletion is offered by long-press here and by the button
        // inside the edit sheet — both of which actually work.
        .contextMenu {
            Button(role: .destructive) {
                delete(target)
            } label: {
                Label("حذف", systemImage: "trash")
            }
        }
        .accessibilityHint("افتح للتعديل، أو اضغط مطولًا للحذف")
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
            return item.dueDay.map { "يوم الاستحقاق \($0)" }
        case .debt(let item):
            var parts = ["الحد الأدنى \(CurrencyFormat.string(item.minimumPayment))"]
            if item.apr > 0 { parts.append("\(item.apr.percentText)% فائدة") }
            if let day = item.dueDay { parts.append("يوم \(day)") }
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
