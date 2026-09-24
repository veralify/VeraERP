import SwiftUI
import SwiftData

/// All records of one kind: tap to edit, swipe to delete, plus to add.
struct EntryListView: View {
    let kind: EntryKind

    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var payments: [DebtPayment]

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

    /// How far through the debt, then the pills and the pay action.
    ///
    /// The bar is the same figure the detail screen shows, from `DebtProgress`,
    /// so the two cannot quote different percentages for the same debt.
    private func debtProgress(_ debt: DebtRecord) -> some View {
        let progress = DebtProgress(debt: debt, payments: payments)

        return VStack(alignment: .leading, spacing: 10) {
            ProgressTrack(progress: progress.fraction, foreground: Theme.textTertiary, fill: Theme.lime)

            HStack(spacing: 8) {
                Pill(
                    text: String(localized: "\(progress.percent)% paid"),
                    style: .muted(dot: progress.hasProgress ? Theme.lime : Theme.textTertiary)
                )
                if debt.apr > 0 {
                    Pill(text: String(localized: "\(debt.apr.percentText)%"), style: .accent(Theme.yellow))
                }

                Spacer(minLength: 8)

                Button { payingDebt = debt } label: {
                    Label("Pay", systemImage: "creditcard")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.lime, in: .capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Record a payment for \(debt.name)")
            }
            // Nothing in this row may be squeezed: without it the pills and the
            // button compress until their labels break mid-word.
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(1)
        }
        .padding(.bottom, 15)
    }

    /// Wraps a row's content in whichever way of opening it the kind deserves.
    @ViewBuilder
    private func rowButton<Content: View>(
        for target: EditTarget,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if case .debt(let item) = target {
            NavigationLink(value: DebtRoute(remoteID: item.remoteID)) { content() }
                .buttonStyle(.pressableRow)
                .accessibilityHint("Open for progress and payments")
        } else {
            Button { editing = target } label: { content() }
                .buttonStyle(.pressableRow)
                .accessibilityHint("Open to edit")
        }
    }

    @ViewBuilder
    private func row(for target: EditTarget) -> some View {
        // The row and the Pay action are siblings, not nested: a Button inside
        // another Button's label does not reliably receive taps, and an overlay
        // would sit on top of the balance.
        VStack(alignment: .leading, spacing: 0) {
            // A debt has a screen of its own — progress and its payment history.
            // Income and expenses are a name and an amount, so they go straight
            // to the editor.
            rowButton(for: target) {
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
                .padding(.top, 15)
                .padding(.bottom, isDebt(target) ? 10 : 15)
                .contentShape(.rect)
            }

            if case .debt(let item) = target {
                debtProgress(item)
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

    private func isDebt(_ target: EditTarget) -> Bool {
        if case .debt = target { return true }
        return false
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
            // Interest moved to a pill below; the due day stays here, where
            // there is room. Three pills plus the pay button did not fit on one
            // line and wrapped mid-word.
            var parts = [String(localized: "Minimum \(CurrencyFormat.string(item.minimumPayment))")]
            if let day = item.dueDay { parts.append(String(localized: "day \(day)")) }
            return parts.joined(separator: " · ")
        }
    }

    private func delete(_ target: EditTarget) {
        switch target {
        case .income(let item):  context.delete(item)
        case .expense(let item): context.delete(item)
        case .debt(let item):    context.deleteDebt(item)
        }
        try? context.save()
    }
}

extension ModelContext {
    /// Deletes a debt together with its payment ledger.
    ///
    /// Payments point at a debt by `remoteID`, and a new debt takes the next id
    /// after the highest — so deleting the newest debt and adding another reused
    /// its id, and the old debt's payments (planned ones included) attached
    /// themselves to the new one: in its history, its due list and its reminders.
    func deleteDebt(_ debt: DebtRecord) {
        // Payments and the board's saved bubble position are keyed by id.
        purgeRecords(forDebt: debt.remoteID, in: self)
        delete(debt)
    }
}
