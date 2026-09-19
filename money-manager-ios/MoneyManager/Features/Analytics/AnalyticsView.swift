import SwiftUI
import SwiftData
import Charts
import MoneyManagerCore

/// Where the money goes, and where the plan takes it.
struct AnalyticsView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    private struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let amount: Decimal
        let color: Color
    }

    /// Where each month's income lands. "Remaining" is what survives after
    /// every committed outflow — clamped, since a deficit is not a slice.
    private var allocation: [Slice] {
        let leftover = max(0, summary.netCashFlow)
        return [
            Slice(label: String(localized: "Expenses"), amount: summary.totalExpenses, color: Theme.yellow),
            Slice(label: String(localized: "Debt payments"), amount: summary.totalDebtMinimums, color: Theme.red),
            Slice(label: String(localized: "Left over"), amount: leftover, color: Theme.lime)
        ].filter { $0.amount > 0 }
    }

    // MARK: - Sankey

    /// Individual expenses stay visible while the diagram can carry them; past
    /// that they collapse into one node, because a phone-width Sankey with a
    /// dozen slivers communicates nothing.
    private var expenseNodes: [SankeyChart.Node] {
        let active = expenses.filter(\.isActive)
        guard active.count > 3 else {
            return active.map { SankeyChart.Node(id: "exp-\($0.persistentModelID.hashValue)", label: $0.name, color: Theme.yellow) }
        }
        return [SankeyChart.Node(id: "exp-all", label: String(localized: "Expenses"), color: Theme.yellow)]
    }

    private var expenseAmounts: [String: Decimal] {
        let active = expenses.filter(\.isActive)
        guard active.count > 3 else {
            return Dictionary(
                active.map { ("exp-\($0.persistentModelID.hashValue)", $0.amount) },
                uniquingKeysWith: +
            )
        }
        return ["exp-all": active.reduce(Decimal(0)) { $0 + $1.amount }]
    }

    private var sankeySources: [SankeyChart.Node] {
        income.filter(\.isActive).map {
            SankeyChart.Node(id: "inc-\($0.persistentModelID.hashValue)", label: $0.name, color: Theme.lime)
        }
    }

    private var sankeyTargets: [SankeyChart.Node] {
        var labels: [(id: String, label: String)] = expenseNodes.map { ($0.id, $0.label) }
        labels += debts.map { ("debt-\($0.remoteID)", $0.name) }
        if summary.netCashFlow > 0 {
            labels.append(("left", String(localized: "Left over")))
        }
        return labels.enumerated().map { index, item in
            SankeyChart.Node(id: item.id, label: item.label, color: Theme.categorical(index))
        }
    }

    /// Money is pooled, so there is no true per-source allocation to report.
    /// Each outflow is therefore split across income sources in proportion to
    /// what each contributes — the standard reading for a pooled account.
    private var sankeyFlows: [SankeyLayout.Flow] {
        let activeIncome = income.filter(\.isActive)
        let totalIncome = activeIncome.reduce(Decimal(0)) { $0 + $1.amount }
        guard totalIncome > 0 else { return [] }

        var outflows: [(id: String, amount: Decimal)] = expenseNodes.compactMap { node in
            guard let amount = expenseAmounts[node.id], amount > 0 else { return nil }
            return (node.id, amount)
        }
        outflows += debts.compactMap { debt in
            debt.minimumPayment > 0 ? ("debt-\(debt.remoteID)", debt.minimumPayment) : nil
        }
        if summary.netCashFlow > 0 {
            outflows.append(("left", summary.netCashFlow))
        }

        return activeIncome.flatMap { source -> [SankeyLayout.Flow] in
            let share = source.amount / totalIncome
            return outflows.map { outflow in
                SankeyLayout.Flow(
                    source: "inc-\(source.persistentModelID.hashValue)",
                    target: outflow.id,
                    value: outflow.amount * share
                )
            }
        }
    }

    private var sankeyCard: some View {
        SankeyCard(
            total: summary.totalIncome,
            caption: "Allocated each month",
            sources: sankeySources,
            targets: sankeyTargets,
            flows: sankeyFlows
        )
    }

    private var hasData: Bool { !income.isEmpty || !expenses.isEmpty || !debts.isEmpty }

    var body: some View {
        ScrollView {
            if hasData {
                VStack(spacing: 18) {
                    if !sankeyFlows.isEmpty { sankeyCard }
                    allocationCard
                    if !debts.isEmpty {
                        payoffCard
                        debtMixCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 108)
            } else {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No data yet",
                    message: "Add your income and expenses to see how your month breaks down."
                )
                .padding(.top, 60)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var allocationCard: some View {
        ChartCard(title: "Where your income goes", subtitle: "How your monthly income splits") {
            if allocation.isEmpty {
                Text("No commitments to show.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(allocation) { slice in
                    SectorMark(
                        angle: .value("Amount", (slice.amount as NSDecimalNumber).doubleValue),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 210)

                VStack(spacing: 10) {
                    ForEach(allocation) { slice in
                        HStack(spacing: 10) {
                            Circle().fill(slice.color).frame(width: 9, height: 9)
                            Text(slice.label)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer(minLength: 8)
                            Text(CurrencyFormat.string(slice.amount))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var payoffCard: some View {
        ChartCard(title: "Debt reduction over time", subtitle: "Remaining balance, month by month") {
            Chart(Array(summary.plan.months.enumerated()), id: \.offset) { index, month in
                AreaMark(
                    x: .value("Month", index),
                    y: .value("Left over", (month.remainingDebt as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Theme.lime.opacity(0.35), Theme.lime.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Month", index),
                    y: .value("Left over", (month.remainingDebt as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(Theme.lime)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    AxisValueLabel {
                        if let index = value.as(Int.self), index < summary.plan.months.count {
                            Text(summary.plan.months[index].month.suffix(2))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    // Default labels use the device locale, which would print
                    // "6.000" next to "€6,000.00" elsewhere in the app.
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Decimal(amount).axisText)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private var debtMixCard: some View {
        ChartCard(title: "Debts by balance", subtitle: "Which one takes the most") {
            Chart(debts, id: \.remoteID) { debt in
                BarMark(
                    x: .value("Balance", (debt.balance as NSDecimalNumber).doubleValue),
                    y: .value("Debt", debt.name)
                )
                .foregroundStyle(debt.apr > 0 ? Theme.red : Theme.blue)
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Decimal(amount).axisText)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: max(120, CGFloat(debts.count) * 54))
        }
    }
}

extension Decimal {
    /// Compact axis label, formatted with the same separators as the currency.
    var axisText: String {
        formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(0))
                .notation(.compactName)
        )
    }
}

/// Dark card wrapper shared by every chart.
struct ChartCard<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}
