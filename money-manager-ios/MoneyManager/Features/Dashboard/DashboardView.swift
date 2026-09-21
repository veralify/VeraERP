import SwiftUI
import SwiftData
import MoneyManagerCore

struct DashboardView: View {
    /// Switches to the Roadmap tab. The card opens the same screen the tab does
    /// rather than pushing a second copy with different chrome.
    var onOpenRoadmap: () -> Void = {}

    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]
    @Query private var snapshots: [MonthlySnapshot]
    @Query private var familyMembers: [FamilyMember]
    @Query private var familyExpenses: [FamilyExpense]

    @Environment(\.modelContext) private var context

    /// Set by the quick-pay chips, which open the payment sheet straight from
    /// the dashboard rather than by way of the debts list.
    @State private var payingDebt: DebtRecord?

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

    /// What the plan looked like when this month began, if the app was open to
    /// see it.
    private var baseline: MonthlySnapshot? {
        let start = MonthlySnapshot.monthStart(for: .now)
        return snapshots.first { $0.month == start }
    }

    /// Records this month's starting figures the first time the app is opened
    /// in it. Idempotent: it only ever inserts when the month has no row.
    private func captureBaselineIfNeeded() {
        guard baseline == nil else { return }
        let state = summary
        context.insert(
            MonthlySnapshot(
                month: MonthlySnapshot.monthStart(for: .now),
                income: state.totalIncome,
                expenses: state.totalExpenses,
                debtMinimums: state.totalDebtMinimums,
                debtBalance: state.totalDebt
            )
        )
        try? context.save()
    }

    /// Content only — the tab bar, title and add sheet belong to `MainTabView`,
    /// so they persist across tab changes instead of being rebuilt per screen.
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard.staggeredAppearance(0)
                planStrip.staggeredAppearance(1)
                metricCards.staggeredAppearance(2)
                roadmapCard.staggeredAppearance(3)
                familyCard.staggeredAppearance(4)
                ProgressSection(
                    netCashFlow: summary.netCashFlow,
                    soonestDueInDays: soonestDueInDays
                )
                debtList.staggeredAppearance(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Clear the floating bar so the last row is never trapped under it.
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
        .task { captureBaselineIfNeeded() }
        .sheet(item: $payingDebt) { DebtPaymentSheet(debt: $0) }
    }

    /// Shared household costs. Its figures stay out of the plan totals above —
    /// those are recurring commitments, these are one-off events between people.
    private var familyCard: some View {
        let start = MonthlySnapshot.monthStart(for: .now)
        let thisMonth = familyExpenses.filter { $0.date >= start }
        let total = thisMonth.reduce(Decimal(0)) { $0 + $1.amount }

        return NavigationLink(value: FamilyRoute()) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 30, height: 30)
                    .background(Theme.blue.opacity(0.16), in: .rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Family")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(familyMembers.isEmpty
                         ? "Split costs with the people you live with"
                         : "\(thisMonth.count) shared this month")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !familyMembers.isEmpty {
                    Text(CurrencyFormat.string(total))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.pressable)
    }

    /// A glance at the payoff route, and the way into the full map.
    @ViewBuilder
    private var roadmapCard: some View {
        let steps = JourneyBuilder.steps(plan: summary.plan, debts: debts.map(\.asDebt))
        let position = steps.firstIndex { $0.month >= JourneyStep.monthKey(for: .now) } ?? 0

        if let step = steps.indices.contains(position) ? steps[position] : nil {
            Button(action: onOpenRoadmap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.blue)
                            .frame(width: 24, height: 24)
                            .background(Theme.blue.opacity(0.16), in: .rect(cornerRadius: 8))

                        Text("Your roadmap")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Step \(position + 1) of \(steps.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text(JourneyStep.title(for: step.month))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }

                    // Distance along the route, not the share of debt the plan
                    // expects to clear — that reads 100% before a euro is paid.
                    ProgressTrack(
                        progress: steps.isEmpty ? 0 : Double(position) / Double(steps.count),
                        foreground: Theme.textTertiary
                    )

                    Text("\(CurrencyFormat.string(step.payment)) this month")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.pressable)
        }
    }

    /// Income, core expenses and debts as their own cards, each carrying what it
    /// has done since the month began.
    private var metricCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(value: EntryKind.income) {
                    MetricCard(
                        title: "Income",
                        icon: "arrow.down.left",
                        accent: Theme.lime,
                        amount: summary.totalIncome,
                        delta: MonthlyDelta.since(
                            baseline?.income, now: summary.totalIncome, risingIsGood: true
                        ),
                        isCompact: true
                    )
                }
                .buttonStyle(.pressable)

                NavigationLink(value: EntryKind.expense) {
                    MetricCard(
                        title: "Core expenses",
                        icon: "arrow.up.right",
                        accent: Theme.yellow,
                        amount: summary.totalExpenses,
                        delta: MonthlyDelta.since(
                            baseline?.expenses, now: summary.totalExpenses, risingIsGood: false
                        ),
                        isCompact: true
                    )
                }
                .buttonStyle(.pressable)
            }
            .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: EntryKind.debt) {
                MetricCard(
                    title: "Debts",
                    icon: "creditcard.fill",
                    accent: Theme.red,
                    amount: summary.totalDebt,
                    delta: MonthlyDelta.since(
                        baseline?.debtBalance, now: summary.totalDebt, risingIsGood: false
                    ),
                    footnote: "\(CurrencyFormat.string(summary.totalDebtMinimums)) due each month"
                )
            }
            .buttonStyle(.pressable)

            if !debts.isEmpty { quickPayRow }
        }
    }

    /// One tap from the dashboard to the payment sheet, already pointed at the
    /// right debt and prefilled with its instalment — recording a payment is
    /// the thing people come back to do, and it was three screens deep.
    ///
    /// Sibling of the debts card rather than inside it: a button nested in a
    /// `NavigationLink` competes with it for the tap.
    private var quickPayRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Record a payment")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 2)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(debts) { debt in
                        Button {
                            payingDebt = debt
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.lime)
                                Text(LocalizedStringKey(debt.name))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(CurrencyFormat.string(debt.minimumPayment))
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surface, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Record a payment for \(debt.name)")
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            // The row is one screen edge to the other, so it must not be
            // clipped by the page's own gutter.
            .scrollClipDisabled()
        }
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
