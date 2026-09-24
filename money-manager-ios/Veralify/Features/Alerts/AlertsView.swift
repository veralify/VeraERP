import SwiftUI
import SwiftData
import VeralifyCore

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

    /// A payment the user planned for a specific date and has not marked paid.
    struct ScheduledPayment: Identifiable {
        let id: PersistentIdentifier
        let debtRemoteID: Int
        let name: String
        let amount: Decimal
        let date: Date
        /// Negative once the date has passed.
        let daysUntil: Int

        var isOverdue: Bool { daysUntil < 0 }
    }

    /// Anything further out than this is not yet worth nagging about.
    static let horizonDays = 30

    let dashboard: DashboardSummary
    let upcoming: [UpcomingBill]
    let scheduled: [ScheduledPayment]
    let itemsMissingDueDate: Int

    var isInDeficit: Bool { dashboard.netCashFlow < 0 }
    var isPlanInfeasible: Bool { hasDebts && !dashboard.plan.isFeasible }

    private let hasDebts: Bool

    /// Total things worth surfacing on the badge.
    var count: Int {
        (isInDeficit ? 1 : 0) + (isPlanInfeasible ? 1 : 0) + upcoming.count + scheduled.count
    }

    /// Main-actor because it builds a `DashboardSummary`, which caches its plan.
    @MainActor
    init(
        income: [IncomeSource],
        expenses: [ExpenseItem],
        debts: [DebtRecord],
        settings: PlanSettings?,
        payments: [DebtPayment] = [],
        now: Date = .now
    ) {
        dashboard = DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings)
        hasDebts = !debts.isEmpty

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let namesByID = Dictionary(uniqueKeysWithValues: debts.map { ($0.remoteID, $0.name) })

        var planned: [ScheduledPayment] = []
        for payment in payments where !payment.isPaid {
            guard let name = namesByID[payment.debtRemoteID] else { continue }
            let days = calendar.dateComponents(
                [.day], from: today, to: calendar.startOfDay(for: payment.date)
            ).day ?? 0
            // Overdue ones stay visible however old they are — an unpaid payment
            // the user planned is exactly the thing they need reminding about.
            guard days <= Self.horizonDays else { continue }
            planned.append(
                ScheduledPayment(
                    id: payment.persistentModelID,
                    debtRemoteID: payment.debtRemoteID,
                    name: name,
                    amount: payment.amount,
                    date: payment.date,
                    daysUntil: days
                )
            )
        }
        scheduled = planned.sorted { $0.daysUntil < $1.daysUntil }

        // A debt with a payment already planned in this window does not also need
        // its generic minimum listed — the planned amount is the deliberate one.
        let debtsWithPlannedPayment = Set(scheduled.map(\.debtRemoteID))

        var bills: [UpcomingBill] = []
        for expense in expenses where expense.isActive {
            guard let day = expense.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= Self.horizonDays
            else { continue }
            bills.append(UpcomingBill(name: expense.name, amount: expense.amount, daysUntil: days, isDebt: false))
        }
        for debt in debts where !debt.isPaidOff && !debtsWithPlannedPayment.contains(debt.remoteID) {
            guard let day = debt.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: day, from: now),
                  days <= Self.horizonDays
            else { continue }
            bills.append(UpcomingBill(name: debt.name, amount: debt.monthlyPayment, daysUntil: days, isDebt: true))
        }
        upcoming = bills.sorted { $0.daysUntil < $1.daysUntil }

        itemsMissingDueDate = expenses.filter { $0.isActive && $0.dueDay == nil }.count
            + debts.filter { !$0.isPaidOff && $0.dueDay == nil }.count
    }
}

/// Bell for the navigation bar, badged with the number of live alerts.
struct AlertsToolbarButton: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]
    @Query private var payments: [DebtPayment]

    let onTap: () -> Void

    private var summary: AlertsSummary {
        AlertsSummary(
            income: income, expenses: expenses, debts: debts,
            settings: settings.first, payments: payments
        )
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
    @Query private var payments: [DebtPayment]

    @Environment(\.dismiss) private var dismiss
    @State private var payingDebt: DebtRecord?

    private var summary: AlertsSummary {
        AlertsSummary(
            income: income, expenses: expenses, debts: debts,
            settings: settings.first, payments: payments
        )
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
            .sheet(item: $payingDebt) { DebtPaymentSheet(debt: $0) }
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

                if !state.scheduled.isEmpty {
                    VStack(spacing: 12) {
                        SectionHeader(title: "Planned payments") {
                            Text("\(state.scheduled.count)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }

                        GroupedCard {
                            ForEach(Array(state.scheduled.enumerated()), id: \.element.id) { index, payment in
                                if index > 0 { RowDivider() }
                                scheduledRow(payment)
                            }
                        }
                    }
                }

                if state.upcoming.isEmpty {
                    if state.count == 0 {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "Nothing needs your attention",
                            message: "Nothing is due in the next 30 days."
                        )
                        .padding(.top, 40)
                    } else if state.scheduled.isEmpty {
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

    /// A payment the user planned. Tapping reopens the debt so it can be marked
    /// paid — an alert you cannot act on is just noise.
    private func scheduledRow(_ payment: AlertsSummary.ScheduledPayment) -> some View {
        Button {
            payingDebt = debts.first { $0.remoteID == payment.debtRemoteID }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(payment.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 8)
                    Text(CurrencyFormat.string(payment.amount))
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }

                HStack(spacing: 10) {
                    Pill(
                        text: payment.date.formatted(.dateTime.day().month(.abbreviated)),
                        style: .muted(dot: payment.isOverdue ? Theme.red : Theme.lime)
                    )
                    if payment.isOverdue {
                        Pill(text: String(localized: "Not paid yet"), style: .accent(Theme.red))
                    } else {
                        Pill(text: String(localized: "Planned"), style: .accent(Theme.lime))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the debt so you can mark it paid")
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
