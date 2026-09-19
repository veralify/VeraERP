import SwiftUI
import SwiftData
import MoneyManagerCore

/// What needs attention: an infeasible plan, then what falls due soonest.
struct AlertsView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    /// Anything further out than this is not yet worth nagging about.
    private let horizonDays = 30

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    struct UpcomingBill: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let daysUntil: Int
        let isDebt: Bool
    }

    private var upcoming: [UpcomingBill] {
        let now = Date()
        var bills: [UpcomingBill] = []

        for expense in expenses where expense.isActive {
            guard let day = expense.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= horizonDays
            else { continue }
            bills.append(
                UpcomingBill(name: expense.name, amount: expense.amount, daysUntil: days, isDebt: false)
            )
        }

        for debt in debts {
            guard let day = debt.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= horizonDays
            else { continue }
            bills.append(
                UpcomingBill(name: debt.name, amount: debt.minimumPayment, daysUntil: days, isDebt: true)
            )
        }

        return bills.sorted { $0.daysUntil < $1.daysUntil }
    }

    private var hasPlanWarning: Bool { !debts.isEmpty && !summary.plan.isFeasible }
    private var hasDeficit: Bool { summary.netCashFlow < 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if hasDeficit {
                    AlertBanner(
                        icon: "exclamationmark.triangle.fill",
                        title: "Your commitments exceed your income",
                        message: "You're \(CurrencyFormat.string(abs(summary.netCashFlow))) short each month. Review your expenses or payments.",
                        accent: Theme.red
                    )
                }

                if hasPlanWarning {
                    AlertBanner(
                        icon: "calendar.badge.exclamationmark",
                        title: "This plan isn't achievable",
                        message: "You'd need \(CurrencyFormat.string(summary.plan.requiredMonthly)) a month across \(summary.plan.targetMonths) months, which is more than you have.",
                        accent: Theme.yellow
                    )
                }

                if upcoming.isEmpty {
                    if !hasDeficit && !hasPlanWarning {
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
                            Text("\(upcoming.count)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }

                        GroupedCard {
                            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, bill in
                                if index > 0 { RowDivider() }
                                billRow(bill)
                            }
                        }
                    }
                }

                // A due date can only be tracked if one was recorded.
                if missingDueDates > 0 {
                    Text("\(missingDueDates) items have no due date, so they can't be flagged.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
    }

    private var missingDueDates: Int {
        expenses.filter { $0.isActive && $0.dueDay == nil }.count
            + debts.filter { $0.dueDay == nil }.count
    }

    private func billRow(_ bill: UpcomingBill) -> some View {
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
