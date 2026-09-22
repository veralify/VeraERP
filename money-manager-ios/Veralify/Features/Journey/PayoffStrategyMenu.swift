import SwiftUI
import SwiftData
import VeralifyCore

extension PayoffStrategy {
    var title: LocalizedStringKey {
        switch self {
        case .highestInterest: "Highest interest first"
        case .smallestBalance: "Smallest balance first"
        case .custom:          "The order I choose"
        }
    }

    /// What picking it actually does. Both real strategies are defensible, so
    /// the app states the trade rather than implying one is a mistake.
    var detail: LocalizedStringKey {
        switch self {
        case .highestInterest: "Spare money goes to the dearest debt"
        case .smallestBalance: "Spare money goes to the smallest debt"
        case .custom:          "Spare money follows your own order"
        }
    }

    var icon: String {
        switch self {
        case .highestInterest: "percent"
        case .smallestBalance: "snowflake"
        case .custom:          "hand.draw"
        }
    }
}

// MARK: - What each method would actually do

/// One method, costed against the user's real debts.
///
/// The comparison is the point. Three names mean nothing; three finish dates and
/// three interest bills mean everything.
struct PayoffMethodQuote: Identifiable {
    let strategy: PayoffStrategy
    /// The monthly budget this method needs to hit the target period.
    let monthly: Decimal
    let totalInterest: Decimal
    /// `yyyy-MM`, or nil when this method cannot clear the debt in the term.
    let finishMonth: String?
    /// The first debt to disappear, which is the whole appeal of a snowball.
    let firstCleared: (name: String, month: String)?
    let isFeasible: Bool

    var id: String { strategy.rawValue }

    static func quote(
        for strategy: PayoffStrategy,
        debts: [Debt],
        income: Decimal,
        expenses: Decimal,
        targetMonths: Int,
        startDate: Date
    ) -> PayoffMethodQuote {
        // Deliberately not `PlanCache`: costing three methods in a row would
        // evict the plan the rest of the app is using, three times over.
        let plan = DebtPayoffEngine.plan(
            debts: debts,
            monthlyIncome: income,
            monthlyExpenses: expenses,
            targetMonths: targetMonths,
            startDate: startDate,
            strategy: strategy
        )
        let summary = JourneyBuilder.summary(plan: plan, debts: debts)
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let first = steps.first { !$0.clearedDebts.isEmpty }

        return PayoffMethodQuote(
            strategy: strategy,
            monthly: plan.requiredMonthly,
            totalInterest: summary.totalInterest,
            finishMonth: summary.finishMonth,
            firstCleared: first.flatMap { step in
                step.clearedDebts.first.map { ($0, step.month) }
            },
            isFeasible: plan.isFeasible
        )
    }
}

// MARK: - The row on the Plan tab

/// The current method, and the way into the comparison.
struct PayoffStrategyRow: View {
    @Bindable var settings: PlanSettings
    let debts: [DebtRecord]
    let income: Decimal
    let expenses: Decimal

    @Environment(\.modelContext) private var context
    @State private var isComparing = false

    var body: some View {
        VStack(spacing: 12) {
            Button { isComparing = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: settings.payoffStrategy.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                        .frame(width: 30, height: 30)
                        .background(Theme.lime.opacity(0.14), in: .rect(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payoff method")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        Text(settings.payoffStrategy.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Spacer(minLength: 8)

                    Text("Compare")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.lime)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.pressable)

            if settings.payoffStrategy == .custom {
                PayoffOrderList(debts: debts)
            }
        }
        .sheet(isPresented: $isComparing) {
            PayoffComparisonSheet(
                selected: settings.payoffStrategy,
                debts: debts,
                income: income,
                expenses: expenses,
                targetMonths: settings.targetMonths,
                startDate: settings.startDate
            ) { chosen in
                settings.payoffStrategy = chosen
                try? context.save()
            }
            .presentationBackground(Theme.background)
        }
    }
}

// MARK: - The comparison

/// All three methods costed side by side, so the choice is made on figures
/// rather than on which name sounds best.
struct PayoffComparisonSheet: View {
    let selected: PayoffStrategy
    let debts: [DebtRecord]
    let income: Decimal
    let expenses: Decimal
    let targetMonths: Int
    let startDate: Date
    let onChoose: (PayoffStrategy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var highlighted: PayoffStrategy
    @State private var quotes: [PayoffMethodQuote] = []

    init(
        selected: PayoffStrategy,
        debts: [DebtRecord],
        income: Decimal,
        expenses: Decimal,
        targetMonths: Int,
        startDate: Date,
        onChoose: @escaping (PayoffStrategy) -> Void
    ) {
        self.selected = selected
        self.debts = debts
        self.income = income
        self.expenses = expenses
        self.targetMonths = targetMonths
        self.startDate = startDate
        self.onChoose = onChoose
        _highlighted = State(initialValue: selected)
    }

    /// The smallest interest bill on offer, which the others are measured
    /// against.
    private var cheapestInterest: Decimal? { quotes.map(\.totalInterest).min() }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        intro
                        ForEach(quotes) { card($0) }
                        footnote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 116)
                }
                .scrollIndicators(.hidden)

                confirmBar
            }
            .navigationTitle("Payoff method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .task { cost() }
        }
    }

    /// Three payoff engines, each bisecting fifty times. Run once when the sheet
    /// appears rather than per render, which would re-cost them on every tap.
    private func cost() {
        guard quotes.isEmpty else { return }
        let values = debts.map(\.asDebt)
        quotes = PayoffStrategy.allCases.map { strategy in
            PayoffMethodQuote.quote(
                for: strategy,
                debts: values,
                income: income,
                expenses: expenses,
                targetMonths: targetMonths,
                startDate: startDate
            )
        }
    }

    private var intro: some View {
        Text("Same debts, same target period. What changes is which debt the spare money goes to — and what that ends up costing.")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var footnote: some View {
        Text("Every debt keeps getting its minimum payment whichever you choose. This only decides where the money left over goes.")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var confirmBar: some View {
        PrimaryButton(
            title: highlighted == selected ? "Keep this method" : "Use this method",
            enabled: true
        ) {
            onChoose(highlighted)
            dismiss()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 20)
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func card(_ quote: PayoffMethodQuote) -> some View {
        let isHighlighted = highlighted == quote.strategy
        let isCurrent = selected == quote.strategy
        let extra = cheapestInterest.map { quote.totalInterest - $0 } ?? 0

        return Button {
            highlighted = quote.strategy
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        if isCurrent {
                            Text("Current method")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Text(quote.strategy.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(quote.strategy.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isHighlighted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21))
                        .foregroundStyle(isHighlighted ? Theme.lime : Theme.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(CurrencyFormat.string(quote.monthly))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("/month")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 8)
                    badge(extra: extra, isFeasible: quote.isFeasible)
                }

                RowDivider()

                VStack(spacing: 7) {
                    factRow(
                        "Interest over the plan",
                        CurrencyFormat.string(quote.totalInterest),
                        tint: extra > 0 ? Theme.red : Theme.green
                    )
                    factRow(
                        "Debt free by",
                        quote.finishMonth.map { JourneyStep.title(for: $0) }
                            ?? String(localized: "Not within the target")
                    )
                    if let first = quote.firstCleared {
                        factRow("First one gone", "\(first.name), \(JourneyStep.title(for: first.month))")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isHighlighted ? Theme.lime : Theme.stroke,
                        lineWidth: isHighlighted ? 2 : 1
                    )
            )
        }
        .buttonStyle(.pressable)
    }

    /// The cheapest wins the accent; the others say what they cost rather than
    /// being marked wrong. Affordability outranks both — a method the household
    /// cannot fund is the only real warning here.
    @ViewBuilder
    private func badge(extra: Decimal, isFeasible: Bool) -> some View {
        if !isFeasible {
            Pill(text: String(localized: "Over budget"), style: .muted(dot: Theme.red))
        } else if extra <= 0 {
            Pill(text: String(localized: "Cheapest"), style: .outlined(Theme.lime))
        } else {
            // Just the difference: "+€51.36 interest" wrapped to two lines
            // inside the pill, and the row directly beneath it already says
            // what the figure is.
            Pill(text: "+\(CurrencyFormat.string(extra))", style: .muted(dot: Theme.yellow))
                .lineLimit(1)
        }
    }

    private func factRow(
        _ label: LocalizedStringKey,
        _ value: String,
        tint: Color = Theme.textPrimary
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - The custom order

/// Debts in the order the surplus will hit them.
///
/// Arrows rather than drag handles: `onMove` needs a `List`, and a `List` inside
/// the Plan tab's `ScrollView` would bring its own scrolling and background.
struct PayoffOrderList: View {
    let debts: [DebtRecord]
    @Environment(\.modelContext) private var context

    var body: some View {
        let ranked = debts.sorted { ($0.priority, $0.remoteID) < ($1.priority, $1.remoteID) }

        GroupedCard {
            ForEach(Array(ranked.enumerated()), id: \.element.remoteID) { position, debt in
                if position > 0 { RowDivider() }
                HStack(spacing: 12) {
                    Text("\(position + 1)")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Theme.surfaceElevated, in: .circle)

                    Text(LocalizedStringKey(debt.name))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(CurrencyFormat.string(debt.balance))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)

                    move(ranked, from: position, by: -1, icon: "chevron.up")
                    move(ranked, from: position, by: 1, icon: "chevron.down")
                }
                .padding(.vertical, 9)
            }
        }
    }

    private func move(
        _ ranked: [DebtRecord],
        from position: Int,
        by offset: Int,
        icon: String
    ) -> some View {
        let destination = position + offset
        let enabled = ranked.indices.contains(destination)

        return Button {
            guard enabled else { return }
            var reordered = ranked
            reordered.swapAt(position, destination)
            // Rewritten from scratch each time so the numbers stay 1, 2, 3 …
            // however they were set before.
            for (rank, debt) in reordered.enumerated() { debt.priority = rank + 1 }
            try? context.save()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? Theme.textSecondary : Theme.textTertiary.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(Theme.surfaceElevated, in: .circle)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityLabel(offset < 0 ? "Move up" : "Move down")
    }
}
