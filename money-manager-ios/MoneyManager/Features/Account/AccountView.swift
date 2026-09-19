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

    @State private var isConfirmingReset = false

    private var planSettings: PlanSettings? { settings.first }

    private var appVersion: String {
        let bundle = Bundle.main.infoDictionary
        let version = bundle?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                planCard
                dataCard
                aboutCard
                resetCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            "Delete all data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your income, expenses and debts will be permanently deleted and setup will start again. This cannot be undone.")
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
                RowDivider()
                infoRow("Currency", "EUR €")
            }
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
        .buttonStyle(.plain)
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
        for item in income { context.delete(item) }
        for item in expenses { context.delete(item) }
        for item in debts { context.delete(item) }
        for item in settings { context.delete(item) }
        try? context.save()
        // Send the user back through setup so the app is never left in a state
        // with no income, no debts and no way to add the first one.
        hasCompletedOnboarding = false
    }
}
