import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for the budgets screen.
struct BudgetsRoute: Hashable {}

/// Monthly limits, and how this month is going against them.
///
/// A budget here is a comparison, not a commitment: it never reaches the payoff
/// engine and never changes what the plan says you owe. Rent is a commitment and
/// lives in the plan; "I would like to keep groceries under €400" is a budget and
/// lives here.
struct BudgetsView: View {
    @Query(sort: \CategoryBudget.limit, order: .reverse) private var budgets: [CategoryBudget]
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var transactions: [TransactionRecord]

    @Environment(\.modelContext) private var context
    @State private var editing: CategoryBudget?
    @State private var isAdding = false

    private var history: BudgetHistory {
        BudgetTracker.history(
            budgets: budgets.map { (category: $0.category, limit: $0.limit) },
            entries: transactions
                .filter { $0.direction == .debit }
                .map { (category: $0.category, amount: $0.amount, date: $0.occurredAt) }
        )
    }

    private var report: BudgetReport {
        let start = MonthlySnapshot.monthStart(for: .now)
        let spending = transactions
            .filter { $0.occurredAt >= start && $0.direction == .debit }
            .map { (category: $0.category, amount: $0.amount) }

        return BudgetTracker.report(
            budgets: budgets.map { (category: $0.category, limit: $0.limit) },
            entries: spending
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    if report.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar.horizontal.page",
                            title: "No budgets yet",
                            message: "Set a monthly limit on a category and this shows how the month is going against it."
                        )
                        PrimaryButton(title: "Set your first budget", enabled: true) { isAdding = true }
                            .padding(.horizontal, 4)
                    } else {
                        summary(report)
                        BudgetHistoryCard(history: history)
                        ForEach(report.lines) { line in
                            Button { editing = budget(for: line.category) } label: {
                                card(line, elapsed: report.monthElapsed)
                            }
                            .buttonStyle(.pressable)
                        }
                        footnote
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Label("New budget", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                }
                .buttonStyle(.pressable)
            }
        }
        .sheet(isPresented: $isAdding) {
            BudgetSheet(existing: nil, taken: Set(budgets.map(\.category)))
                .presentationBackground(Theme.background)
        }
        .sheet(item: $editing) { budget in
            BudgetSheet(existing: budget, taken: Set(budgets.map(\.category)))
                .presentationBackground(Theme.background)
        }
    }

    private func budget(for category: String) -> CategoryBudget? {
        budgets.first { $0.category == category }
    }

    // MARK: - Summary

    /// One sentence before any of the detail. The number that matters is what
    /// is left across everything, or how many limits have already gone.
    private func summary(_ report: BudgetReport) -> some View {
        let days = BudgetTracker.daysLeft(in: .now)

        return VStack(alignment: .leading, spacing: 10) {
            Text(CurrencyFormat.string(report.totalRemaining))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(report.totalRemaining >= 0 ? Theme.onAccent : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Two phrases rather than one sentence with two counts in it: a
            // single string needing plural agreement on both numbers is a
            // translator's trap, and Arabic has six plural forms to get wrong.
            HStack(spacing: 6) {
                Text(report.overCount > 0
                     ? "\(report.overCount) of \(report.lines.count) over the limit"
                     : "left across \(report.lines.count) budgets")
                Text("·")
                Text("\(days) days to go")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(report.totalRemaining >= 0 ? Theme.onAccent.opacity(0.8) : Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            report.totalRemaining >= 0 ? Theme.lime : Theme.redSurface,
            in: .rect(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - One budget

    private func card(_ line: BudgetLine, elapsed: Double) -> some View {
        let ahead = line.isAheadOfPace(monthElapsed: elapsed)
        let accent: Color = line.isOver ? Theme.red : (ahead ? Theme.yellow : Theme.lime)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalizedStringKey(line.category))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if line.isOver {
                    Pill(text: String(localized: "Over"), style: .muted(dot: Theme.red))
                } else if ahead {
                    Pill(text: String(localized: "Ahead of pace"), style: .muted(dot: Theme.yellow))
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(CurrencyFormat.string(abs(line.remaining)))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(line.isOver ? "over" : "left")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            ProgressTrack(progress: line.fraction, foreground: accent, fill: accent)

            HStack(spacing: 8) {
                Text("\(CurrencyFormat.string(line.spent)) of \(CurrencyFormat.string(line.limit))")
                    .monospacedDigit()
                Text("·")
                Text("\(Int((line.fraction * 100).rounded()))% spent")
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text("\(line.count) entries")
            }
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var footnote: some View {
        Text("Budgets are measured against what you log, nothing else. They do not change your plan or what your debts cost.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Add and edit

/// Set or change one category's limit.
struct BudgetSheet: View {
    let existing: CategoryBudget?
    /// Categories that already have a budget, so the picker cannot create a
    /// second limit on one — the unique constraint would refuse the save and
    /// the sheet would simply appear to do nothing.
    let taken: Set<String>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var category: String
    @State private var amount: String
    @State private var isConfirmingDelete = false

    init(existing: CategoryBudget?, taken: Set<String>) {
        self.existing = existing
        self.taken = taken
        _category = State(initialValue: existing?.category
            ?? EntryPresets.categories.first { !taken.contains($0) }
            ?? EntryPresets.categories[0])
        _amount = State(initialValue: existing.map { $0.limit.editableText } ?? "")
    }

    private var available: [String] {
        EntryPresets.categories.filter { $0 == existing?.category || !taken.contains($0) }
    }

    private var parsed: Decimal? { AmountParser.parse(amount) }
    private var canSave: Bool { (parsed ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if available.isEmpty {
                            Text("Every category already has a budget. Edit one instead.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            categoryPicker
                        }

                        VStack(spacing: 14) {
                            FieldRow(
                                label: "Monthly limit",
                                placeholder: "0.00",
                                text: $amount,
                                keyboard: .decimalPad
                            )
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        PrimaryButton(title: "Save budget", enabled: canSave, action: save)

                        if existing != nil {
                            Button("Remove this budget", role: .destructive) { isConfirmingDelete = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.red)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle(existing == nil ? "New budget" : "Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .confirmationDialog("Remove this budget?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { remove() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The entries stay. Only the limit goes.")
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(available, id: \.self) { option in
                    Button { category = option } label: {
                        Text(LocalizedStringKey(option))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(category == option ? Theme.onAccent : Theme.textSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(category == option ? Theme.lime : Theme.surfaceElevated, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func save() {
        guard let limit = parsed else { return }

        if let existing {
            existing.category = category
            existing.limit = limit
        } else {
            context.insert(CategoryBudget(category: category, limit: limit))
        }
        try? context.save()
        dismiss()
    }

    private func remove() {
        guard let existing else { return }
        context.delete(existing)
        try? context.save()
        dismiss()
    }
}
