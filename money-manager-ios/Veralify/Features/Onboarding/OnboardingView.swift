import SwiftUI
import SwiftData
import VeralifyCore

/// First-run setup.
///
/// The app previously seeded one household's real debts on launch, which meant
/// every new user opened onto a deficit that was not theirs. Nothing is written
/// to the store until the flow is completed, and demo data is opt-in and
/// labelled as demo.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step: OnboardingStep = .welcome
    @State private var income: [DraftEntry] = []
    @State private var expenses: [DraftEntry] = []
    @State private var debts: [DraftDebt] = []
    @State private var targetMonths: Int = 16
    /// The success screen reads its tiles from the drafts, which the demo path
    /// never fills — so it reads the saved records instead.
    @State private var usedSampleData = false

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
        }
        .animation(.snappy(duration: 0.25), value: step)
    }

    // MARK: - Chrome

    @ViewBuilder
    private var header: some View {
        if let index = step.progressIndex {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        if let previous = step.previous { step = previous }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Theme.surface, in: .circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Back")

                    Spacer()

                    Text("Step \(index + 1) of \(OnboardingStep.progressSteps.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                StepProgress(current: index, total: OnboardingStep.progressSteps.count)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:  welcomeStep
        case .income:   incomeStep
        case .expenses: expensesStep
        case .debts:    debtsStep
        case .target:   targetStep
        case .summary:  summaryStep
        case .success:  successStep
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text("€")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.lime.readableForeground)
                    .frame(width: 62, height: 62)
                    .background(Theme.lime, in: .rect(cornerRadius: 18))

                Text("Your money, with a clear plan")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Record your income, expenses and debts, then get a monthly payoff plan that tells you exactly when you'll be done.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    highlight(icon: "chart.line.downtrend.xyaxis", text: "A payoff plan that clears the priciest debt first")
                    highlight(icon: "bell.badge", text: "See what's due before it lands")
                    highlight(icon: "lock.shield", text: "Your data stays on your device")
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                PrimaryButton(title: "Let's set up") { step = .income }
                SecondaryButton(title: "Try it with sample data") { finishWithSampleData() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private func highlight(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.lime)
                .frame(width: 32, height: 32)
                .background(Theme.lime.opacity(0.14), in: .circle)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var incomeStep: some View {
        EntryStep(
            title: "What do you earn?",
            subtitle: "Add what you actually receive each month. You can change this later.",
            namePlaceholder: "e.g. Salary",
            accent: Theme.lime,
            entries: $income,
            primaryTitle: income.isEmpty ? "Skip" : "Continue",
            onContinue: { step = .expenses }
        )
    }

    private var expensesStep: some View {
        EntryStep(
            title: "What are your fixed expenses?",
            subtitle: "Rent, bills, subscriptions — any recurring monthly commitment. Don't include debt payments here; you'll add those next.",
            namePlaceholder: "e.g. Rent",
            accent: Theme.yellow,
            entries: $expenses,
            primaryTitle: expenses.isEmpty ? "Skip" : "Continue",
            onContinue: { step = .debts }
        )
    }

    private var debtsStep: some View {
        DebtStep(
            debts: $debts,
            onContinue: { step = .target }
        )
    }

    private var targetStep: some View {
        OnboardingScaffold(
            title: "In how many months do you want to be debt free?",
            subtitle: "We'll work out the monthly payment needed, and tell you honestly if the period isn't realistic on your income."
        ) {
            VStack(spacing: 18) {
                Text("\(targetMonths)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.lime.readableForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
                    .overlay(alignment: .bottom) {
                        Text("months")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.lime.readableForeground.opacity(0.7))
                            .padding(.bottom, 12)
                    }

                Stepper(value: $targetMonths, in: 3...120, step: 1) {
                    Text("Target period")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.inner))

                HStack(spacing: 8) {
                    ForEach([12, 16, 24, 36], id: \.self) { months in
                        Button {
                            targetMonths = months
                        } label: {
                            Text("\(months)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(targetMonths == months ? Theme.onAccent : Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    targetMonths == months ? Theme.lime : Theme.surfaceElevated,
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        } actions: {
            PrimaryButton(title: "Continue") { step = .summary }
        }
    }

    private var summaryStep: some View {
        let plan = previewPlan()
        return OnboardingScaffold(
            title: "Here's your plan",
            subtitle: "Check the numbers before you start. Everything can be changed later."
        ) {
            VStack(spacing: 14) {
                AccentCard(
                    eyebrow: "Net available flow",
                    amount: netCashFlow,
                    caption: netCashFlow >= 0 ? "After expenses and payments" : "Your commitments exceed your income",
                    progress: 0,
                    progressLabel: String(localized: "\(targetMonths) months"),
                    accent: netCashFlow >= 0 ? Theme.lime : Theme.red
                )

                GroupedCard {
                    summaryRow("Monthly income", totalIncome, Theme.green)
                    RowDivider()
                    summaryRow("Fixed expenses", totalExpenses, Theme.yellow)
                    RowDivider()
                    summaryRow("Total debt", totalDebt, Theme.red)
                    if !debts.isEmpty {
                        RowDivider()
                        summaryRow("Monthly payment needed", plan.requiredMonthly, Theme.blue)
                    }
                }

                if !debts.isEmpty && !plan.isFeasible {
                    // Say this before setup finishes, not after — it is the most
                    // useful thing the app can tell someone in this position.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.red)
                        Text("On your current income this period isn't realistic. Try a longer one, or review your expenses.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.red.opacity(0.14), in: .rect(cornerRadius: Theme.Radius.inner))
                }
            }
        } actions: {
            PrimaryButton(title: "Finish setup") { commitAndCelebrate() }
            if !debts.isEmpty && !plan.isFeasible {
                SecondaryButton(title: "Adjust the period") { step = .target }
            }
        }
    }

    private var successStep: some View {
        let plan = previewPlan()
        return SetupSuccessView(
            cards: successCards,
            statusText: debts.isEmpty || plan.isFeasible ? "Achievable" : "Needs adjusting",
            statusIsGood: debts.isEmpty || plan.isFeasible,
            targetMonths: targetMonths,
            onContinue: onFinish
        )
    }

    /// The user's own entries as tiles. Largest first, so the front — and
    /// sharpest — card is the one that matters most.
    private var successCards: [ScatterCard] {
        if usedSampleData { return sampleCards }

        let largestDebt = debts.map(\.balance).max() ?? 1
        let debtCards = debts.sorted { $0.balance > $1.balance }.map { debt in
            ScatterCard(
                title: debt.name,
                subtitle: String(localized: "Debt"),
                amount: CurrencyFormat.string(debt.balance),
                fill: largestDebt > 0 ? NSDecimalNumber(decimal: debt.balance / largestDebt).doubleValue : 0,
                accent: debt.apr > 0 ? Theme.red : Theme.blue
            )
        }

        let incomeCards = income.map { entry in
            ScatterCard(
                title: entry.name,
                subtitle: String(localized: "Income"),
                amount: CurrencyFormat.string(entry.amount),
                fill: 1,
                accent: Theme.lime
            )
        }

        let expenseCards = expenses.map { entry in
            ScatterCard(
                title: entry.name,
                subtitle: String(localized: "Expense"),
                amount: CurrencyFormat.string(entry.amount),
                fill: totalIncome > 0 ? NSDecimalNumber(decimal: entry.amount / totalIncome).doubleValue : 0.4,
                accent: Theme.yellow
            )
        }

        // Back to front: context first, the headline debt last.
        return Array((incomeCards + expenseCards + debtCards).prefix(5))
    }

    /// Tiles built from what was just written to the store, for the demo path.
    private var sampleCards: [ScatterCard] {
        let savedDebts = (try? context.fetch(FetchDescriptor<DebtRecord>())) ?? []
        let savedIncome = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        let largest = savedDebts.map(\.balance).max() ?? 1

        let incomeCards = savedIncome.map { entry in
            ScatterCard(
                title: entry.name,
                subtitle: String(localized: "Income"),
                amount: CurrencyFormat.string(entry.amount),
                fill: 1,
                accent: Theme.lime
            )
        }
        let debtCards = savedDebts.sorted { $0.balance > $1.balance }.map { debt in
            ScatterCard(
                title: debt.name,
                subtitle: String(localized: "Debt"),
                amount: CurrencyFormat.string(debt.balance),
                fill: largest > 0 ? NSDecimalNumber(decimal: debt.balance / largest).doubleValue : 0,
                accent: debt.apr > 0 ? Theme.red : Theme.blue
            )
        }
        return Array((incomeCards + debtCards).prefix(5))
    }

    private func summaryRow(_ label: LocalizedStringKey, _ amount: Decimal, _ accent: Color) -> some View {
        HStack {
            Circle().fill(accent).frame(width: 9, height: 9)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(CurrencyFormat.string(amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived

    private var totalIncome: Decimal { income.reduce(0) { $0 + $1.amount } }
    private var totalExpenses: Decimal { expenses.reduce(0) { $0 + $1.amount } }
    private var totalDebt: Decimal { debts.reduce(0) { $0 + $1.balance } }
    private var totalMinimums: Decimal { debts.reduce(0) { $0 + $1.minimumPayment } }
    private var netCashFlow: Decimal { totalIncome - totalExpenses - totalMinimums }

    private func previewPlan() -> PayoffPlan {
        DebtPayoffEngine.plan(
            debts: debts.enumerated().map { index, draft in
                Debt(
                    id: index + 1,
                    name: draft.name,
                    balance: draft.balance,
                    apr: draft.apr,
                    minimumPayment: draft.minimumPayment,
                    dueDay: draft.dueDay,
                    priority: index + 1
                )
            },
            monthlyIncome: totalIncome,
            monthlyExpenses: totalExpenses,
            targetMonths: targetMonths,
            startDate: .now
        )
    }

    // MARK: - Commit

    private func commitAndCelebrate() {
        finish()
        step = .success
    }

    private func finish() {
        for entry in income {
            context.insert(IncomeSource(name: entry.name, amount: entry.amount))
        }
        for entry in expenses {
            context.insert(ExpenseItem(name: entry.name, amount: entry.amount))
        }
        for (index, draft) in debts.enumerated() {
            context.insert(
                DebtRecord(
                    remoteID: index + 1,
                    name: draft.name,
                    balance: draft.balance,
                    apr: draft.apr,
                    minimumPayment: draft.minimumPayment,
                    // Collected on the way in, and dropped here until now —
                    // which left every onboarded debt with no reminders and an
                    // immediate "add a due date" nag.
                    dueDay: draft.dueDay,
                    priority: index + 1
                )
            )
        }
        context.insert(PlanSettings(targetMonths: targetMonths, startDate: .now))
        try? context.save()
    }

    private func finishWithSampleData() {
        SampleData.insertDemoData(context)
        usedSampleData = true
        step = .success
    }
}
