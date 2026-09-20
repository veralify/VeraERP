import SwiftUI
import SwiftData
import MoneyManagerCore

struct DashboardView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    /// Days until the nearest due payment, or nil when nothing is scheduled.
    private var soonestDueInDays: Int? {
        let now = Date()
        let days = (expenses.filter(\.isActive).compactMap(\.dueDay) + debts.compactMap(\.dueDay))
            .compactMap { BillSchedule.daysUntil(dueDay: $0, from: now) }
        return days.min()
    }

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    /// Content only — the tab bar, title and add sheet belong to `MainTabView`,
    /// so they persist across tab changes instead of being rebuilt per screen.
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard.staggeredAppearance(0)
                planStrip.staggeredAppearance(1)
                ProgressSection(
                    netCashFlow: summary.netCashFlow,
                    soonestDueInDays: soonestDueInDays
                )
                breakdown.staggeredAppearance(3)
                debtList.staggeredAppearance(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Clear the floating bar so the last row is never trapped under it.
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
    }

    /// The headline figure, on a fill that states whether it is good news.
    private var heroCard: some View {
        AccentCard(
            eyebrow: "Net available flow",
            amount: summary.netCashFlow,
            caption: summary.netCashFlow >= 0
                ? "After expenses and payments"
                : "Your commitments exceed your income this month",
            progress: summary.progressFraction,
            progressLabel: String(localized: "\(summary.progressPercent)% paid off"),
            accent: summary.netCashFlow >= 0 ? Theme.lime : Theme.red
        )
    }

    /// Mirrors the reference's timer row: the plan's key numbers as pills.
    private var planStrip: some View {
        HStack(spacing: 10) {
            Pill(
                text: CurrencyFormat.string(summary.plan.requiredMonthly),
                style: .outlined(summary.plan.isFeasible ? Theme.lime : Theme.red)
            )
            Pill(
                text: summary.plan.isFeasible
                    ? String(localized: "Achievable")
                    : String(localized: "Needs adjusting"),
                style: .muted(dot: summary.plan.isFeasible ? Theme.green : Theme.red)
            )
            Pill(text: String(localized: "\(summary.plan.targetMonths) months"))
            Spacer(minLength: 0)
        }
    }

    private var breakdown: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Monthly flow") {
                Text("\(income.count + expenses.count) items")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            GroupedCard {
                NavigationLink(value: EntryKind.income) {
                    DetailRow(
                        title: "Monthly income",
                        subtitle: "The sum of your active income sources.",
                        value: CurrencyFormat.string(summary.totalIncome),
                        statusText: String(localized: "Active"),
                        statusDot: Theme.green,
                        tag: String(localized: "Income"),
                        tagColor: Theme.lime
                    )
                }
                .buttonStyle(.pressableRow)

                RowDivider()

                NavigationLink(value: EntryKind.expense) {
                    DetailRow(
                        title: "Core expenses",
                        subtitle: "Your fixed monthly commitments.",
                        value: CurrencyFormat.string(summary.totalExpenses),
                        statusText: String(localized: "Monthly"),
                        statusDot: Theme.yellow,
                        tag: String(localized: "Expense"),
                        tagColor: Theme.yellow
                    )
                }
                .buttonStyle(.pressableRow)

                RowDivider()

                NavigationLink(value: EntryKind.debt) {
                    DetailRow(
                        title: "Debt payments",
                        subtitle: "The minimum due across all your debts.",
                        value: CurrencyFormat.string(summary.totalDebtMinimums),
                        statusText: String(localized: "Due"),
                        statusDot: Theme.red,
                        tag: String(localized: "Payment"),
                        tagColor: Theme.red
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }

    private var debtList: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Debts") {
                Text(CurrencyFormat.string(summary.totalDebt))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            GroupedCard {
                ForEach(Array(debts.enumerated()), id: \.element.remoteID) { index, debt in
                    if index > 0 { RowDivider() }
                    NavigationLink(value: EntryKind.debt) {
                    DetailRow(
                        title: LocalizedStringKey(debt.name),
                        subtitle: "Minimum \(CurrencyFormat.string(debt.minimumPayment)) per month.",
                        value: CurrencyFormat.string(debt.balance),
                        statusText: debt.apr > 0
                            ? String(localized: "\(debt.apr.percentText)% interest")
                            : String(localized: "No interest"),
                        statusDot: debt.apr > 0 ? Theme.red : Theme.green,
                        tag: debt.apr > 0 ? String(localized: "Priority") : String(localized: "Standard"),
                        tagColor: debt.apr > 0 ? Theme.red : Theme.blue
                    )
                    }
                    .buttonStyle(.pressableRow)
                }
            }
        }
    }
}

/// Derives every dashboard figure from the stored records.
///
/// Deliberately a plain value type computed from the queries rather than an
/// observable object: the payoff plan is a pure function of the data, so there
/// is no separate state to keep in sync.
struct DashboardSummary {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let totalDebt: Decimal
    /// Sum of every debt's minimum payment — a monthly obligation, so it has to
    /// come out of cash flow even though it is not in the `expenses` table.
    let totalDebtMinimums: Decimal
    let plan: PayoffPlan

    init(income: [IncomeSource], expenses: [ExpenseItem], debts: [DebtRecord], settings: PlanSettings?) {
        totalIncome = income.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
        totalExpenses = expenses.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
        totalDebt = debts.reduce(Decimal(0)) { $0 + $1.balance }
        totalDebtMinimums = debts.reduce(Decimal(0)) { $0 + $1.minimumPayment }
        plan = DebtPayoffEngine.plan(
            debts: debts.map(\.asDebt),
            monthlyIncome: totalIncome,
            monthlyExpenses: totalExpenses,
            targetMonths: settings?.targetMonths ?? 16,
            startDate: settings?.startDate ?? .now
        )
    }

    /// What is genuinely uncommitted each month.
    ///
    /// Matches the web app's `/api/dashboard` definition — income less
    /// expenses, debt minimums and savings contributions — with one deliberate
    /// difference: the web wraps this in `money()`, which clamps negatives to
    /// zero, so a household in deficit is shown €0.00 under a reassuring
    /// headline. A finance app must not hide a shortfall, so this returns the
    /// real figure and lets the UI switch to its warning state.
    ///
    /// Savings contributions are not subtracted yet because savings goals are
    /// not modelled on iOS; add them here when they land.
    var netCashFlow: Decimal { totalIncome - totalExpenses - totalDebtMinimums }

    var progressFraction: Double {
        guard plan.totalDebt > 0 else { return 0 }
        let cleared = plan.totalDebt - plan.projectedRemaining
        let fraction = (cleared / plan.totalDebt).doubleValue
        return min(max(fraction, 0), 1)
    }

    var progressPercent: Int { Int((progressFraction * 100).rounded()) }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
