import SwiftUI
import SwiftData
import MoneyManagerCore

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
                    .buttonStyle(.plain)
                    .accessibilityLabel("رجوع")

                    Spacer()

                    Text("الخطوة \(index + 1) من \(OnboardingStep.progressSteps.count)")
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

                Text("أموالك، بخطة واضحة")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("سجّل دخلك ومصاريفك وديونك، ثم احصل على خطة سداد شهرية تعرف بالضبط متى تنتهي.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    highlight(icon: "chart.line.downtrend.xyaxis", text: "خطة سداد بطريقة الأعلى فائدة أولًا")
                    highlight(icon: "bell.badge", text: "تابع استحقاقاتك القادمة قبل موعدها")
                    highlight(icon: "lock.shield", text: "بياناتك محفوظة على جهازك فقط")
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                PrimaryButton(title: "لنبدأ الإعداد") { step = .income }
                SecondaryButton(title: "تجربة ببيانات نموذجية") { finishWithSampleData() }
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
            title: "ما مصادر دخلك؟",
            subtitle: "أضف صافي ما تستلمه شهريًا. يمكنك تعديل ذلك لاحقًا.",
            namePlaceholder: "مثال: الراتب",
            accent: Theme.lime,
            entries: $income,
            primaryTitle: income.isEmpty ? "تخطٍّ" : "متابعة",
            onContinue: { step = .expenses }
        )
    }

    private var expensesStep: some View {
        EntryStep(
            title: "ما مصاريفك الثابتة؟",
            subtitle: "الإيجار، الفواتير، الاشتراكات — أي التزام شهري متكرر. لا تُدرج أقساط الديون هنا؛ ستضيفها في الخطوة التالية.",
            namePlaceholder: "مثال: الإيجار",
            accent: Theme.yellow,
            entries: $expenses,
            primaryTitle: expenses.isEmpty ? "تخطٍّ" : "متابعة",
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
            title: "خلال كم شهر تريد إنهاء ديونك؟",
            subtitle: "سنحسب القسط الشهري اللازم، ونخبرك بصراحة إن كانت المدة غير واقعية بدخلك الحالي."
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
                        Text("شهرًا")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.lime.readableForeground.opacity(0.7))
                            .padding(.bottom, 12)
                    }

                Stepper(value: $targetMonths, in: 3...120, step: 1) {
                    Text("المدة المستهدفة")
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
                        .buttonStyle(.plain)
                    }
                }
            }
        } actions: {
            PrimaryButton(title: "متابعة") { step = .summary }
        }
    }

    private var summaryStep: some View {
        let plan = previewPlan()
        return OnboardingScaffold(
            title: "هذه خطتك",
            subtitle: "راجع الأرقام قبل البدء. كل شيء قابل للتعديل لاحقًا."
        ) {
            VStack(spacing: 14) {
                AccentCard(
                    eyebrow: "صافي التدفق المتاح",
                    amount: netCashFlow,
                    caption: netCashFlow >= 0 ? "بعد المصاريف والأقساط" : "التزاماتك تتجاوز دخلك",
                    progress: 0,
                    progressLabel: "\(targetMonths) شهر",
                    accent: netCashFlow >= 0 ? Theme.lime : Theme.red
                )

                GroupedCard {
                    summaryRow("الدخل الشهري", totalIncome, Theme.green)
                    RowDivider()
                    summaryRow("المصاريف الثابتة", totalExpenses, Theme.yellow)
                    RowDivider()
                    summaryRow("إجمالي الديون", totalDebt, Theme.red)
                    if !debts.isEmpty {
                        RowDivider()
                        summaryRow("القسط الشهري المطلوب", plan.requiredMonthly, Theme.blue)
                    }
                }

                if !debts.isEmpty && !plan.isFeasible {
                    // Say this before setup finishes, not after — it is the most
                    // useful thing the app can tell someone in this position.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.red)
                        Text("بدخلك الحالي، هذه المدة غير واقعية. جرّب مدة أطول أو راجع مصاريفك.")
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
            PrimaryButton(title: "ابدأ الاستخدام") { finish() }
            if !debts.isEmpty && !plan.isFeasible {
                SecondaryButton(title: "تعديل المدة") { step = .target }
            }
        }
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
                    priority: index + 1
                )
            )
        }
        context.insert(PlanSettings(targetMonths: targetMonths, startDate: .now))
        try? context.save()
        onFinish()
    }

    private func finishWithSampleData() {
        SampleData.insertDemoData(context)
        onFinish()
    }
}
