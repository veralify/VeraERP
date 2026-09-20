import SwiftUI
import SwiftData
import MoneyManagerCore

/// What currently needs attention, derived once and shared.
///
/// Both the nav-bar badge and the alerts screen read this, so the badge can
/// never claim a number the screen does not show.
struct AlertsSummary {
    struct UpcomingBill: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let daysUntil: Int
        let isDebt: Bool
    }

    /// Anything further out than this is not yet worth nagging about.
    static let horizonDays = 30

    let dashboard: DashboardSummary
    let upcoming: [UpcomingBill]
    let itemsMissingDueDate: Int

    var isInDeficit: Bool { dashboard.netCashFlow < 0 }
    var isPlanInfeasible: Bool { hasDebts && !dashboard.plan.isFeasible }

    private let hasDebts: Bool

    /// Total things worth surfacing on the badge.
    var count: Int {
        (isInDeficit ? 1 : 0) + (isPlanInfeasible ? 1 : 0) + upcoming.count
    }

    init(
        income: [IncomeSource],
        expenses: [ExpenseItem],
        debts: [DebtRecord],
        settings: PlanSettings?,
        now: Date = .now
    ) {
        dashboard = DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings)
        hasDebts = !debts.isEmpty

        var bills: [UpcomingBill] = []
        for expense in expenses where expense.isActive {
            guard let day = expense.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= Self.horizonDays
            else { continue }
            bills.append(UpcomingBill(name: expense.name, amount: expense.amount, daysUntil: days, isDebt: false))
        }
        for debt in debts {
            guard let day = debt.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= Self.horizonDays
            else { continue }
            bills.append(UpcomingBill(name: debt.name, amount: debt.minimumPayment, daysUntil: days, isDebt: true))
        }
        upcoming = bills.sorted { $0.daysUntil < $1.daysUntil }

        itemsMissingDueDate = expenses.filter { $0.isActive && $0.dueDay == nil }.count
            + debts.filter { $0.dueDay == nil }.count
    }
}

/// Bell for the navigation bar, badged with the number of live alerts.
struct AlertsToolbarButton: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    let onTap: () -> Void

    private var summary: AlertsSummary {
        AlertsSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    var body: some View {
        let count = summary.count
        Button(action: onTap) {
            Image(systemName: count > 0 ? "bell.badge.fill" : "bell")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(count > 0 ? Theme.red : Theme.textSecondary)
                .symbolRenderingMode(count > 0 ? .hierarchical : .monochrome)
                .symbolEffect(.bounce, value: count)
                .frame(width: 34, height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(count > 0 ? "Alerts, \(count) needing attention" : "Alerts")
    }
}

/// What needs attention: an infeasible plan, then what falls due soonest.
struct AlertsView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.dismiss) private var dismiss

    private var summary: AlertsSummary {
        AlertsSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.lime)
                }
            }
        }
    }

    private var content: some View {
        let state = summary
        return ScrollView {
            VStack(spacing: 18) {
                if state.isInDeficit {
                    AlertBanner(
                        icon: "exclamationmark.triangle.fill",
                        title: "Your commitments exceed your income",
                        message: "You're \(CurrencyFormat.string(abs(state.dashboard.netCashFlow))) short each month. Review your expenses or payments.",
                        accent: Theme.red
                    )
                }

                if state.isPlanInfeasible {
                    AlertBanner(
                        icon: "calendar.badge.exclamationmark",
                        title: "This plan isn't achievable",
                        message: "You'd need \(CurrencyFormat.string(state.dashboard.plan.requiredMonthly)) a month across \(state.dashboard.plan.targetMonths) months, which is more than you have.",
                        accent: Theme.yellow
                    )
                }

                if state.upcoming.isEmpty {
                    if state.count == 0 {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "Nothing needs your attention",
                            message: "Nothing is due in the next 30 days."
                        )
                        .padding(.top, 40)
                    } else {
                        Text("Nothing is due in the next 30 days.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                } else {
                    VStack(spacing: 12) {
                        SectionHeader(title: "Upcoming payments") {
                            Text("\(state.upcoming.count)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }

                        GroupedCard {
                            ForEach(Array(state.upcoming.enumerated()), id: \.element.id) { index, bill in
                                if index > 0 { RowDivider() }
                                billRow(bill)
                            }
                        }
                    }
                }

                // A due date can only be tracked if one was recorded.
                if state.itemsMissingDueDate > 0 {
                    Text("\(state.itemsMissingDueDate) items have no due date, so they can't be flagged.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func billRow(_ bill: AlertsSummary.UpcomingBill) -> some View {
        let urgent = bill.daysUntil <= 3
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(bill.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(CurrencyFormat.string(bill.amount))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(spacing: 10) {
                Pill(
                    text: bill.daysUntil == 0
                        ? String(localized: "Today")
                        : String(localized: "in \(bill.daysUntil) days"),
                    style: .muted(dot: urgent ? Theme.red : Theme.blue)
                )
                Pill(
                    text: bill.isDebt ? String(localized: "Payment") : String(localized: "Expense"),
                    style: .accent(bill.isDebt ? Theme.red : Theme.yellow)
                )
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

/// Full-width warning banner.
struct AlertBanner: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.13), in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
