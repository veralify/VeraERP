import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for the cash-flow breakdown.
struct CashFlowRoute: Hashable {}

/// Where the headline figure comes from.
///
/// Today's largest number is net available flow, and until now it was the one
/// thing on the screen that led nowhere — a total with no way to ask what is in
/// it. This is the arithmetic, one line per term, and every line opens the
/// records behind it.
struct CashFlowView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    terms
                    result
                    note
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Net available flow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var terms: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "This month") { EmptyView() }

            GroupedCard {
                term(
                    kind: .income,
                    title: "Income",
                    detail: "\(income.filter(\.isActive).count) sources",
                    amount: summary.totalIncome,
                    sign: "+",
                    accent: Theme.lime
                )
                RowDivider()
                term(
                    kind: .expense,
                    title: "Core expenses",
                    detail: "\(expenses.filter(\.isActive).count) recurring",
                    amount: summary.totalExpenses,
                    sign: "−",
                    accent: Theme.yellow
                )
                RowDivider()
                term(
                    kind: .debt,
                    title: "Debt payments",
                    detail: "minimums on \(debts.count) debts",
                    amount: summary.totalDebtMinimums,
                    sign: "−",
                    accent: Theme.red
                )
            }
        }
    }

    private func term(
        kind: EntryKind,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        amount: Decimal,
        sign: String,
        accent: Color
    ) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 8)

                Text("\(sign)\(CurrencyFormat.string(amount))")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
    }

    private var result: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("What's left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.85))
            Spacer(minLength: 8)
            Text(CurrencyFormat.string(summary.netCashFlow))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            summary.netCashFlow >= 0 ? Theme.lime : Theme.red,
            in: .rect(cornerRadius: Theme.Radius.card)
        )
    }

    private var note: some View {
        Text("Debt payments count against what's left because they are due every month, the same as rent. Anything you pay above the minimum comes out of what's left over.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
