import SwiftUI
import SwiftData

/// Plan settings, what is stored, and the ways out.
struct AccountView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]
    @Query private var transactions: [TransactionRecord]
    @Query private var questCompletions: [QuestCompletion]
    @Query private var payments: [DebtPayment]
    @Query private var snapshots: [MonthlySnapshot]
    @Query private var familyMembers: [FamilyMember]
    @Query private var familyExpenses: [FamilyExpense]
    @Query private var familySettlements: [FamilySettlement]
    @Query private var documents: [StoredDocument]

    @State private var isConfirmingReset = false
    @State private var isShowingRestartNote = false
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode
    /// Mirrors `Language.current`, but as state so the picker updates the row
    /// straight away rather than only after a relaunch.
    @State private var language = Language.current

    private var planSettings: PlanSettings? { settings.first }

    private var appVersion: String {
        let bundle = Bundle.main.infoDictionary
        let version = bundle?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        planCard
                        documentsCard
                        displayCard
                        dataCard
                        aboutCard
                        resetCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            // The Account screen is presented as a sheet, so it has its own
            // navigation stack. A destination registered in `RootView` is on a
            // different stack entirely and the link silently does nothing.
            .navigationDestination(for: VaultRoute.self) { _ in
                IDVaultView()
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.lime)
                }
            }
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your income, expenses, debts and recorded entries will be permanently deleted and setup will start again. This cannot be undone.")
        }
        .alert("Reopen to finish", isPresented: $isShowingRestartNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Close and reopen Veralify to see it in \(language.title).")
        }
    }

    private var planCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Plan") { EmptyView() }

            GroupedCard {
                HStack {
                    Text("Target period")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    if let planSettings {
                        Stepper(
                            value: Binding(
                                get: { planSettings.targetMonths },
                                set: { planSettings.targetMonths = $0; try? context.save() }
                            ),
                            in: 3...120
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                        Text("\(planSettings.targetMonths) months")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    } else {
                        Text("—").foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.vertical, 12)

                RowDivider()

                infoRow("Payoff method", String(localized: "Highest interest first"))
            }
        }
    }

    /// Passports and ID cards. Lives here rather than in the tab bar: it is
    /// something you keep, not something you check daily.
    private var documentsCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Documents") { EmptyView() }

            NavigationLink(value: VaultRoute()) {
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                        .frame(width: 34, height: 34)
                        .background(Theme.lime.opacity(0.16), in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Passports and IDs")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Scan once, copy any field, get told before they expire")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 8)

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
    }

    /// Currency and language. A language change needs a relaunch, so the row
    /// says so rather than looking broken until the user happens to restart.
    private var displayCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Display") { EmptyView() }

            GroupedCard {
                HStack {
                    Text("Currency")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(SupportedCurrency.all) { currency in
                            Text("\(currency.symbol)  \(String(localized: currency.name))")
                                .tag(currency.code)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.textPrimary)
                }
                .padding(.vertical, 8)

                RowDivider()

                HStack {
                    Text("Language")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Picker("Language", selection: $language) {
                        ForEach(Language.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .tint(Theme.textPrimary)
                    .onChange(of: language) { _, newValue in
                        AppSettings.setLanguage(newValue)
                        isShowingRestartNote = true
                    }
                }
                .padding(.vertical, 8)
            }

            Text("Amounts change straight away. A new language applies when you reopen the app.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var dataCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Your data") { EmptyView() }
            GroupedCard {
                infoRow("Income sources", "\(income.count)")
                RowDivider()
                infoRow("Expenses", "\(expenses.count)")
                RowDivider()
                infoRow("Debts", "\(debts.count)")
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "About") { EmptyView() }
            GroupedCard {
                infoRow("Version", appVersion)
                RowDivider()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                    Text("Your data is stored on this device only and is never sent to a server.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var resetCard: some View {
        Button {
            isConfirmingReset = true
        } label: {
            Text("Delete all data and start over")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.red.opacity(0.13), in: .capsule)
        }
        .buttonStyle(.pressable)
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func resetEverything() {
        // Every store the app owns. Leaving transactions or quest history
        // behind made "delete all data" a lie — the ledger and the day's
        // progress survived a reset that claimed to wipe everything.
        for item in income { context.delete(item) }
        for item in expenses { context.delete(item) }
        for item in debts { context.delete(item) }
        for item in settings { context.delete(item) }
        for item in transactions { context.delete(item) }
        for item in questCompletions { context.delete(item) }
        for item in payments { context.delete(item) }
        for item in snapshots { context.delete(item) }
        for item in familyMembers { context.delete(item) }
        for item in familyExpenses { context.delete(item) }
        for item in familySettlements { context.delete(item) }
        for item in documents { context.delete(item) }
        try? context.save()
        // Send the user back through setup so the app is never left in a state
        // with no income, no debts and no way to add the first one.
        hasCompletedOnboarding = false
        dismiss()
    }
}
