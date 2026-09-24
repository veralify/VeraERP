import SwiftUI
import SwiftData
import VeralifyCore

/// Where the household stands today.
///
/// Deliberately short. It used to carry eight blocks, two of which were cards
/// whose only job was to switch to a tab already on screen, and one of which
/// listed the debts a second time. What is left answers one question — what is
/// left this month, and what is owed — and offers the one action people come
/// back to perform.
struct DashboardView: View {
    /// Switches to the Plan tab. The plan strip summarises the plan, so tapping
    /// it opens the plan rather than a second copy of it.
    var onOpenPlan: () -> Void = {}

    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]
    @Query private var losses: [MoneyLoss]
    @Query private var snapshots: [MonthlySnapshot]
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var payments: [DebtPayment]

    @Environment(\.modelContext) private var context

    /// Set by the quick-pay chips, which open the payment sheet straight from
    /// the dashboard rather than by way of the debts list.
    @State private var payingDebt: DebtRecord?
    @State private var isLoggingLoss = false

    /// Two metric cards side by side leave each about 150pt; at accessibility
    /// text sizes that is too narrow for a title and a figure, so they stack.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The due cards scroll sideways, so their width is free to grow with the
    /// text; a fixed 208 truncated the name at larger sizes.
    @ScaledMetric(relativeTo: .subheadline) private var dueCardWidth: CGFloat = 208

    /// Days until the nearest due payment, or nil when nothing is scheduled.
    private var soonestDueInDays: Int? {
        let now = Date()
        let owing = debts.filter { !$0.isPaidOff }
        let days = (expenses.filter(\.isActive).compactMap(\.dueDay) + owing.compactMap(\.dueDay))
            .compactMap { BillSchedule.daysUntil(dueDay: $0, from: now) }
        return days.min()
    }

    private var summary: DashboardSummary {
        DashboardSummary(
            income: income, expenses: expenses, debts: debts, settings: settings.first, losses: losses
        )
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
                // Near the top: photographing a receipt at the till is the
                // one action here that cannot wait until later.
                ScanReceiptEntry().staggeredAppearance(1)
                planStrip.staggeredAppearance(1)
                dueSoon.staggeredAppearance(2)
                metricCards.staggeredAppearance(2)
                lossesSection.staggeredAppearance(3)
                todaySection.staggeredAppearance(3)
                // Last, under its own heading: the streak and the daily quests
                // are encouragement, and encouragement does not belong between
                // two financial facts.
                ProgressSection(
                    netCashFlow: summary.netCashFlow,
                    soonestDueInDays: soonestDueInDays
                )
                .staggeredAppearance(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Clear the floating bar so the last row is never trapped under it.
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
        // Pull down to sync with the account.
        .syncOnRefresh()
        .task { captureBaselineIfNeeded() }
        .sheet(item: $payingDebt) { DebtPaymentSheet(debt: $0) }
        .sheet(isPresented: $isLoggingLoss) {
            LossSheet()
                .presentationBackground(Theme.background)
        }
    }

    /// Income, core expenses and debts as their own cards, each carrying what it
    /// has done since the month began.
    private var metricCards: some View {
        let pairLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return VStack(spacing: 12) {
            pairLayout {
                NavigationLink(value: EntryKind.income) {
                    MetricCard(
                        title: "Income",
                        icon: "arrow.down.left",
                        accent: Theme.lime,
                        amount: summary.totalIncome,
                        delta: MonthlyDelta.since(
                            baseline?.income, now: summary.totalIncome, risingIsGood: true
                        ),
                        // Variable pay not yet logged this month is counted at
                        // its expected figure; say so rather than pass it off
                        // as what arrived.
                        footnote: summary.incomeIsEstimated ? "Includes an estimate" : nil,
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
            // With the cards' own `maxHeight: .infinity`, this makes the pair
            // share the taller card's height instead of ending unevenly.
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

            quickPayRow
        }
    }

    /// One tap from the dashboard to the payment sheet, already pointed at the
    /// right debt and prefilled with its instalment — recording a payment is
    /// the thing people come back to do, and it was three screens deep.
    ///
    /// Sibling of the debts card rather than inside it: a button nested in a
    /// `NavigationLink` competes with it for the tap.
    ///
    /// Anything already sitting in "Due soon" is left out: that card carries the
    /// same debt with its date attached and opens the same sheet, and listing a
    /// debt twice on one screen is how this dashboard got crowded in the first
    /// place. So this row is the debts nothing is chasing you about yet.
    @ViewBuilder
    private var quickPayRow: some View {
        let dated = Set(dueItems.compactMap { $0.debt?.remoteID })
        let rest = debts.filter { !$0.isPaidOff && !dated.contains($0.remoteID) }

        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Record a payment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 2)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(rest) { debt in
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
                                    Text(CurrencyFormat.string(debt.monthlyPayment))
                                        .font(.subheadline.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Theme.surface, in: .capsule)
                                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                                // The capsule is about 40pt tall; an invisible
                                // margin brings the target to 44 without making
                                // the chip itself any bigger.
                                .padding(.vertical, 2)
                                .contentShape(.rect)
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
    }

    // MARK: - Money lost

    /// This month's losses, newest first.
    private var lossesThisMonth: [MoneyLoss] {
        let calendar = Calendar.current
        return losses
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    /// Money that went missing this month, and the way to record more.
    ///
    /// Beside the figures it lowers: a loss comes straight off the net flow in
    /// the hero card, so the place to log one is on the same screen, not behind
    /// the Add button (which records money moving, not money gone).
    private var lossesSection: some View {
        let items = lossesThisMonth

        return VStack(spacing: 12) {
            SectionHeader(title: "Money lost") {
                if !items.isEmpty {
                    Text(CurrencyFormat.string(summary.totalLosses))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.red)
                }
            }

            if !items.isEmpty {
                GroupedCard {
                    ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, loss in
                        if index > 0 { RowDivider() }
                        lossRow(loss)
                    }
                }
            }

            Button { isLoggingLoss = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.red)
                    Text("Log money lost")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
    }

    private func lossRow(_ loss: MoneyLoss) -> some View {
        HStack(spacing: 12) {
            Image(systemName: loss.reason.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.red)
                .frame(width: 30, height: 30)
                .background(Theme.red.opacity(0.13), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(loss.reason.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(loss.note.isEmpty
                     ? loss.date.formatted(.dateTime.day().month(.abbreviated))
                     : "\(loss.date.formatted(.dateTime.day().month(.abbreviated))) · \(loss.note)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(verbatim: "−" + CurrencyFormat.string(loss.amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.red)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(loss)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Touch and hold to delete")
    }

    // MARK: - Due soon

    /// One thing the household owes on a particular day.
    private struct DueItem: Identifiable {
        let id: String
        let name: String
        let amount: Decimal
        let date: Date
        /// Negative once the day has passed.
        let daysUntil: Int
        /// The debt to open when tapped. Nil for a recurring expense, which the
        /// app does not record payments against.
        let debt: DebtRecord?

        var isOverdue: Bool { daysUntil < 0 }
        var isToday: Bool { daysUntil == 0 }
        var isPressing: Bool { daysUntil <= 3 }
    }

    /// Anything owed inside a fortnight, plus anything already late.
    ///
    /// A month's worth lives behind the bell; the near stuff belongs on the
    /// screen you open every day. "The 1st is next week and rent comes out" is
    /// not a notification, it is the thing you came to find out.
    ///
    /// Fourteen days rather than seven: household bills cluster on a couple of
    /// dates in the month, so a week-long window is empty most of the time and
    /// the section would blink in and out of existence.
    private var dueItems: [DueItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let horizon = 14
        var items: [DueItem] = []

        // Payments the user planned for a date and has not marked paid. These
        // win over the debt's generic minimum: the planned amount is the
        // deliberate one. Only a payment inside the window counts, though — one
        // planned for months ahead must not hide the instalment due this week.
        var planned = Set<Int>()
        for payment in payments where !payment.isPaid {
            guard let debt = debts.first(where: { $0.remoteID == payment.debtRemoteID }) else { continue }
            let day = calendar.startOfDay(for: payment.date)
            let days = calendar.dateComponents([.day], from: today, to: day).day ?? 0
            guard days <= horizon else { continue }
            planned.insert(debt.remoteID)
            items.append(
                DueItem(
                    id: "planned-\(payment.persistentModelID.hashValue)",
                    name: debt.name,
                    amount: payment.amount,
                    date: day,
                    daysUntil: days,
                    debt: debt
                )
            )
        }

        for debt in debts where !debt.isPaidOff && !planned.contains(debt.remoteID) {
            guard let dueDay = debt.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: dueDay, from: .now),
                  days <= horizon,
                  let date = calendar.date(byAdding: .day, value: days, to: today)
            else { continue }
            items.append(
                DueItem(
                    id: "debt-\(debt.remoteID)",
                    name: debt.name,
                    amount: debt.monthlyPayment,
                    date: date,
                    daysUntil: days,
                    debt: debt
                )
            )
        }

        for expense in expenses where expense.isActive {
            guard let dueDay = expense.dueDay,
                  let days = BillSchedule.daysUntil(dueDay: dueDay, from: .now),
                  days <= horizon,
                  let date = calendar.date(byAdding: .day, value: days, to: today)
            else { continue }
            items.append(
                DueItem(
                    id: "expense-\(expense.persistentModelID.hashValue)",
                    name: expense.name,
                    amount: expense.amount,
                    date: date,
                    daysUntil: days,
                    debt: nil
                )
            )
        }

        return items.sorted { $0.daysUntil < $1.daysUntil }
    }

    @ViewBuilder
    private var dueSoon: some View {
        let items = dueItems

        if !items.isEmpty {
            // 12 between header and content, the same as the Today section.
            VStack(spacing: 12) {
                SectionHeader(title: "Due soon") {
                    Text(CurrencyFormat.string(items.reduce(Decimal(0)) { $0 + $1.amount }))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(items) { dueCard($0) }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                // The row runs edge to edge, so the page's gutter must not clip
                // the card that is half off screen.
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func dueCard(_ item: DueItem) -> some View {
        let accent: Color = item.isOverdue || item.isToday
            ? Theme.red
            : (item.isPressing ? Theme.yellow : Theme.blue)

        let card = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    Text(item.date.formatted(.dateTime.day()))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    Text(item.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(accent.opacity(0.8))
                }
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.14), in: .rect(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.name))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(whenLabel(item))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CurrencyFormat.string(item.amount))
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if item.debt != nil {
                    Text("Pay")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.lime)
                }
            }
        }
        .padding(14)
        .frame(width: dueCardWidth, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(item.isOverdue || item.isToday ? accent.opacity(0.5) : Theme.stroke, lineWidth: 1)
        )

        // A debt can be paid from here; a recurring expense has nothing to
        // record against it, so it opens the list it belongs to instead.
        if let debt = item.debt {
            Button { payingDebt = debt } label: { card }
                .buttonStyle(.pressable)
                .accessibilityLabel("Record a payment for \(item.name)")
        } else {
            NavigationLink(value: EntryKind.expense) { card }
                .buttonStyle(.pressable)
        }
    }

    private func whenLabel(_ item: DueItem) -> LocalizedStringKey {
        if item.daysUntil < 0 { return "\(-item.daysUntil) days late" }
        if item.daysUntil == 0 { return "Today" }
        if item.daysUntil == 1 { return "Tomorrow" }
        return "In \(item.daysUntil) days"
    }

    /// What you logged today, with the full history one push behind it.
    ///
    /// This is the part of the retired Entries tab worth seeing daily. The rest
    /// of it — every entry ever recorded, by day, by scope — is a reference, and
    /// references live behind a link.
    private var todaySection: some View {
        let calendar = Calendar.current
        // Same-day only: an entry dated later in the week was listed as today's.
        let today = transactions.filter { calendar.isDateInToday($0.occurredAt) }

        return VStack(spacing: 12) {
            SectionHeader(title: "Today") {
                NavigationLink(value: LedgerRoute()) {
                    HStack(spacing: 3) {
                        Text("All entries")
                            .font(.caption.weight(.bold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Theme.lime)
                    // A caption link is about 16pt tall. Pad the hit area out
                    // to 44 and take the padding back from the layout, so the
                    // header row stays the height of "Due soon"'s.
                    .padding(.vertical, 14)
                    .padding(.leading, 12)
                    .contentShape(.rect)
                    .padding(.vertical, -14)
                    .padding(.leading, -12)
                }
                .buttonStyle(.pressable)
            }

            if today.isEmpty {
                NavigationLink(value: LedgerRoute()) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Nothing logged yet today")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
                }
                .buttonStyle(.pressable)
            } else {
                // Not `GroupedCard`: its 16pt inset stacked on the row's own 14
                // put the entries 30pt in from the card edge, twice the inset
                // of every other card here. The row brings its own padding, so
                // the card only supplies the surface, with dividers inset to
                // match the row content.
                VStack(spacing: 0) {
                    ForEach(Array(today.prefix(4).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { RowDivider().padding(.horizontal, 14) }
                        entryRow(record)
                    }
                }
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            }
        }
    }

    /// The ledger's own row, so the two screens cannot drift apart in what an
    /// entry looks like.
    private func entryRow(_ record: TransactionRecord) -> some View {
        NavigationLink(value: LedgerRoute()) {
            TransactionRow(record: record)
        }
        .buttonStyle(.pressableRow)
    }

    /// What has actually come off the debt since the app first saw it.
    ///
    /// The bar used to show `DashboardSummary.progressFraction` — the share of
    /// the debt the *plan* expects to clear — which is 100% the moment a
    /// feasible plan exists. The screenshot that started this was a full green
    /// bar reading "100% paid off" directly above a balance of €14,716.10.
    ///
    /// This measures against the earliest month the app has a record of, so it
    /// starts at nothing and only moves when a balance does.
    private var clearedSoFar: (amount: Decimal, fraction: Double)? {
        guard let earliest = snapshots.min(by: { $0.month < $1.month }),
              earliest.debtBalance > 0
        else { return nil }

        let cleared = max(earliest.debtBalance - summary.totalDebt, 0)
        let fraction = (cleared / earliest.debtBalance).doubleValue
        return (cleared, min(max(fraction, 0), 1))
    }

    /// The headline figure, on a fill that states whether it is good news.
    ///
    /// Tapping it opens the arithmetic behind it. It was the biggest number on
    /// the screen and the only one that led nowhere.
    private var heroCard: some View {
        let cleared = clearedSoFar

        return NavigationLink(value: CashFlowRoute()) {
            AccentCard(
                eyebrow: "Net available flow",
                amount: summary.netCashFlow,
                caption: summary.netCashFlow >= 0
                    ? "After expenses and payments"
                    : "Your commitments exceed your income this month",
                progress: cleared?.fraction ?? 0,
                progressLabel: progressLabel(for: cleared),
                accent: summary.netCashFlow >= 0 ? Theme.lime : Theme.red
            )
        }
        .buttonStyle(.pressable)
    }

    private func progressLabel(for cleared: (amount: Decimal, fraction: Double)?) -> String {
        guard summary.totalDebt > 0 else { return String(localized: "Debt-free") }
        guard let cleared, cleared.amount > 0 else { return String(localized: "Nothing paid off yet") }
        return String(localized: "\(CurrencyFormat.string(cleared.amount)) paid off")
    }

    /// The plan's key numbers as pills — and a way into the plan itself, which
    /// is what they are a summary of.
    private var planStrip: some View {
        Button(action: onOpenPlan) {
            planPills
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Your payoff plan")
    }

    private var planPills: some View {
        HStack(spacing: 10) {
            // Three pills and a chevron need about 350pt with "Needs
            // adjusting", more than a 375pt phone leaves inside the gutters,
            // and far more in Arabic or at large text. When one line will not
            // hold them, the months pill drops to a second line rather than
            // every pill squeezing its text onto two.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    requiredPill
                    feasibilityPill
                    monthsPill
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        requiredPill
                        feasibilityPill
                    }
                    monthsPill
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .contentShape(.rect)
    }

    private var requiredPill: some View {
        Pill(
            text: CurrencyFormat.string(summary.plan.requiredMonthly),
            style: .outlined(summary.plan.isFeasible ? Theme.lime : Theme.red)
        )
    }

    private var feasibilityPill: some View {
        Pill(
            text: summary.plan.isFeasible
                ? String(localized: "Achievable")
                : String(localized: "Needs adjusting"),
            style: .muted(dot: summary.plan.isFeasible ? Theme.green : Theme.red)
        )
    }

    private var monthsPill: some View {
        Pill(text: String(localized: "\(summary.plan.targetMonths) months"))
    }

}

/// Derives every dashboard figure from the stored records.
///
/// Deliberately a plain value type computed from the queries rather than an
/// observable object: the payoff plan is a pure function of the data, so there
/// is no separate state to keep in sync.
struct DashboardSummary {
    /// Income for this month: what variable income actually paid once it is
    /// logged, an estimate until then, and fixed income as typed.
    let totalIncome: Decimal
    /// Income the payoff plan budgets with. Differs from `totalIncome` only for
    /// variable income, where the plan uses the recent average so that one
    /// unusual month does not rewrite the schedule.
    let planIncome: Decimal
    /// True while some variable income has nothing logged for this month, so
    /// `totalIncome` is partly an estimate.
    let incomeIsEstimated: Bool
    /// Money lost this month. Comes off this month's leftover only.
    let totalLosses: Decimal
    let totalExpenses: Decimal
    let totalDebt: Decimal
    /// Sum of every debt's minimum payment — a monthly obligation, so it has to
    /// come out of cash flow even though it is not in the `expenses` table.
    let totalDebtMinimums: Decimal
    let plan: PayoffPlan

    /// Main-actor because the plan is cached, and every caller is a view.
    @MainActor
    init(
        income: [IncomeSource],
        expenses: [ExpenseItem],
        debts: [DebtRecord],
        settings: PlanSettings?,
        losses: [MoneyLoss] = [],
        now: Date = .now
    ) {
        let activeIncome = income.filter(\.isActive)
        let thisMonth = activeIncome.map { $0.thisMonth(asOf: now) }
        totalIncome = thisMonth.reduce(Decimal(0)) { $0 + $1.amount }
        incomeIsEstimated = thisMonth.contains { $0.isEstimate }
        planIncome = activeIncome.reduce(Decimal(0)) { $0 + $1.planAmount(asOf: now) }
        totalLosses = LossLedger.total(
            losses.map { (date: $0.date, amount: $0.amount) }, inMonthOf: now, calendar: .current
        )
        totalExpenses = expenses.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
        totalDebt = debts.reduce(Decimal(0)) { $0 + $1.balance }
        // What leaves each month, not what the lender's floor is: money the
        // user has committed on top is gone from the leftover too.
        totalDebtMinimums = debts.reduce(Decimal(0)) { $0 + $1.monthlyPayment }
        plan = PlanCache.plan(
            debts: debts.map(\.asDebt),
            monthlyIncome: planIncome,
            monthlyExpenses: totalExpenses,
            targetMonths: settings?.targetMonths ?? 16,
            startDate: settings?.startDate ?? PlanCache.sessionStart,
            strategy: settings?.payoffStrategy ?? .highestInterest
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
    /// Money lost this month comes off here too: it is gone from what is left,
    /// even though it does not recur and so never touches the payoff plan.
    ///
    /// Savings contributions are not subtracted yet because savings goals are
    /// not modelled on iOS; add them here when they land.
    var netCashFlow: Decimal { totalIncome - totalExpenses - totalDebtMinimums - totalLosses }

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
