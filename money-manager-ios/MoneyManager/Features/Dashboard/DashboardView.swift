import SwiftUI
import SwiftData
import MoneyManagerCore

struct DashboardView: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    private var summary: DashboardSummary {
        DashboardSummary(income: income, expenses: expenses, debts: debts, settings: settings.first)
    }

    /// Content only — the tab bar, title and add sheet belong to `MainTabView`,
    /// so they persist across tab changes instead of being rebuilt per screen.
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                planStrip
                breakdown
                debtList
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
            eyebrow: "صافي التدفق المتاح",
            amount: summary.netCashFlow,
            caption: summary.netCashFlow >= 0
                ? "بعد المصاريف والأقساط"
                : "التزاماتك تتجاوز دخلك هذا الشهر",
            progress: summary.progressFraction,
            progressLabel: "\(summary.progressPercent)% مسدد",
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
                text: summary.plan.isFeasible ? "قابلة للتنفيذ" : "تحتاج تعديل",
                style: .muted(dot: summary.plan.isFeasible ? Theme.green : Theme.red)
            )
            Pill(text: "\(summary.plan.targetMonths) شهر")
            Spacer(minLength: 0)
        }
    }

    private var breakdown: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "التدفق الشهري") {
                Text("\(income.count + expenses.count) بند")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            GroupedCard {
                NavigationLink(value: EntryKind.income) {
                    DetailRow(
                        title: "الدخل الشهري",
                        subtitle: "مجموع مصادر الدخل النشطة.",
                        value: CurrencyFormat.string(summary.totalIncome),
                        statusText: "نشط",
                        statusDot: Theme.green,
                        tag: "دخل",
                        tagColor: Theme.lime
                    )
                }
                .buttonStyle(.plain)

                RowDivider()

                NavigationLink(value: EntryKind.expense) {
                    DetailRow(
                        title: "المصاريف الأساسية",
                        subtitle: "الالتزامات الشهرية الثابتة.",
                        value: CurrencyFormat.string(summary.totalExpenses),
                        statusText: "شهري",
                        statusDot: Theme.yellow,
                        tag: "مصروف",
                        tagColor: Theme.yellow
                    )
                }
                .buttonStyle(.plain)

                RowDivider()

                NavigationLink(value: EntryKind.debt) {
                    DetailRow(
                        title: "أقساط الديون",
                        subtitle: "الحد الأدنى المستحق على كل الديون.",
                        value: CurrencyFormat.string(summary.totalDebtMinimums),
                        statusText: "مستحق",
                        statusDot: Theme.red,
                        tag: "قسط",
                        tagColor: Theme.red
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var debtList: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "الديون") {
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
                        subtitle: "الحد الأدنى \(CurrencyFormat.string(debt.minimumPayment)) شهريًا.",
                        value: CurrencyFormat.string(debt.balance),
                        statusText: debt.apr > 0 ? "\(debt.apr.percentText)% فائدة" : "بدون فائدة",
                        statusDot: debt.apr > 0 ? Theme.red : Theme.green,
                        tag: debt.apr > 0 ? "أولوية" : "عادي",
                        tagColor: debt.apr > 0 ? Theme.red : Theme.blue
                    )
                    }
                    .buttonStyle(.plain)
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
