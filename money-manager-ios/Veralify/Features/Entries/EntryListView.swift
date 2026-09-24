import SwiftUI
import SwiftData
import VeralifyCore

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
    @State private var loggingIncome: IncomeSource?

    private var targets: [EditTarget] {
        switch kind {
        case .income:  income.map(EditTarget.income)
        case .expense: expenses.map(EditTarget.expense)
        case .debt:    debts.map(EditTarget.debt)
        }
    }

    private var total: Decimal {
        switch kind {
        // This month's figure, so the total matches the Income card it opened from.
        case .income:  income.filter(\.isActive).reduce(0) { $0 + $1.thisMonth().amount }
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
        .sheet(item: $loggingIncome) { source in
            IncomeActualSheet(source: source)
                .presentationBackground(Theme.background)
        }
    }

    private var totalCard: some View {
        // On a shared baseline: centred, the smaller label floated above the
        // figure's baseline and the pair read as two separate things.
        HStack(alignment: .firstTextBaseline) {
            Text(kind == .debt ? "Total balance" : "Monthly total")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(CurrencyFormat.string(total))
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(kind.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
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

        // 4pt rather than 10: the Pay button's 44pt tap area adds 6pt above
        // the capsules, so the visible gap under the bar is still 10.
        return VStack(alignment: .leading, spacing: 4) {
            ProgressTrack(progress: progress.fraction, foreground: Theme.textTertiary, fill: Theme.lime)

            // One row when the pills and the button fit; at large type or in
            // a longer translation the button drops under the pills rather
            // than squeezing them until the labels truncate.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    debtPills(debt, progress: progress)
                    Spacer(minLength: 8)
                    payButton(debt)
                }
                // Spacing chosen against the button's invisible 6pt margin:
                // 10 under the bar, 8 between the pills and the capsule.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        debtPills(debt, progress: progress)
                    }
                    .padding(.top, 6)
                    payButton(debt)
                }
            }
            // Nothing in this row may be squeezed: without it the pills and the
            // button compress until their labels break mid-word.
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(1)
        }
        // 15pt below the pills as before: the Pay button's tap area now
        // reaches 6pt past its capsule, which makes up the difference.
        .padding(.bottom, 9)
    }

    @ViewBuilder
    private func debtPills(_ debt: DebtRecord, progress: DebtProgress) -> some View {
        Pill(
            text: String(localized: "\(progress.percent)% paid"),
            style: .muted(dot: progress.hasProgress ? Theme.lime : Theme.textTertiary)
        )
        if debt.apr > 0 {
            Pill(text: String(localized: "\(debt.apr.percentText)%"), style: .accent(Theme.yellow))
        }
    }

    private func payButton(_ debt: DebtRecord) -> some View {
        Button { payingDebt = debt } label: {
            Label("Pay", systemImage: "creditcard")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.lime, in: .capsule)
                // The capsule is about 32pt tall; the tap area is 44.
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Record a payment for \(debt.name)")
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
                            .lineLimit(2)
                        if let detail = detail(for: target) {
                            Text(detail)
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    // The amount keeps its width and one line; a long name
                    // wraps instead of breaking the figure across two lines.
                    Text(CurrencyFormat.string(amount(for: target)))
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(1)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 15)
                .padding(.bottom, hasFooter(target) ? 10 : 15)
                .contentShape(.rect)
            }

            if case .debt(let item) = target {
                debtProgress(item)
            }
            if case .income(let item) = target, item.incomeKind == .variable {
                incomeLogRow(item)
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

    /// Rows that carry a second line of controls under the name and amount.
    private func hasFooter(_ target: EditTarget) -> Bool {
        switch target {
        case .debt: true
        case .income(let item): item.incomeKind == .variable
        case .expense: false
        }
    }

    /// Variable pay is only known once it has arrived, so its row says whether
    /// this month is logged and offers to log it — the figure beside the name
    /// is an estimate until then.
    private func incomeLogRow(_ source: IncomeSource) -> some View {
        let isLogged = source.logged(inMonthOf: .now) != nil
        return HStack(spacing: 8) {
            Pill(
                text: isLogged
                    ? String(localized: "Logged this month")
                    : String(localized: "Estimate"),
                style: .muted(dot: isLogged ? Theme.lime : Theme.yellow)
            )
            Spacer(minLength: 8)
            Button { loggingIncome = source } label: {
                Label(isLogged ? "Update" : "Log this month", systemImage: "square.and.pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.lime, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Log what \(source.name) paid this month")
        }
        .lineLimit(1)
        .padding(.bottom, 9)
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
        // This month's figure: what variable pay actually brought in once logged.
        case .income(let item):  item.thisMonth().amount
        case .expense(let item): item.amount
        case .debt(let item):    item.balance
        }
    }

    private func detail(for target: EditTarget) -> String? {
        switch target {
        case .income(let item):
            guard item.incomeKind == .variable else { return String(localized: "Fixed") }
            return String(localized: "Variable · plan uses \(CurrencyFormat.string(item.planAmount()))")
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
