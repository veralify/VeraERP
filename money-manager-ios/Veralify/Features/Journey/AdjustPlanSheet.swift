import SwiftUI
import SwiftData
import VeralifyCore

/// Everything that shapes the plan, in one place.
///
/// The two dials that decide the route sat loose at the bottom of the Plan tab,
/// and the three lists they act on — income, expenses, debts — were reachable
/// only from the other end of the app. A plan you cannot adjust from the screen
/// that shows it is a plan you do not really own.
struct AdjustPlanSheet: View {
    @Query(sort: \IncomeSource.createdAt) private var income: [IncomeSource]
    @Query(sort: \ExpenseItem.createdAt) private var expenses: [ExpenseItem]
    @Query(sort: \DebtRecord.remoteID) private var debts: [DebtRecord]
    @Query private var settings: [PlanSettings]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        if let planSettings = settings.first {
                            targetCard(planSettings)

                            VStack(spacing: 12) {
                                SectionHeader(title: "Payoff method") { EmptyView() }
                                PayoffStrategyRow(
                                    settings: planSettings,
                                    debts: debts,
                                    income: income.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount },
                                    expenses: expenses.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount }
                                )
                            }
                        }

                        VStack(spacing: 12) {
                            SectionHeader(title: "What the plan is built from") { EmptyView() }

                            GroupedCard {
                                sourceRow(
                                    kind: .income,
                                    count: income.filter(\.isActive).count,
                                    total: income.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount },
                                    accent: Theme.lime
                                )
                                RowDivider()
                                sourceRow(
                                    kind: .expense,
                                    count: expenses.filter(\.isActive).count,
                                    total: expenses.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.amount },
                                    accent: Theme.yellow
                                )
                                RowDivider()
                                sourceRow(
                                    kind: .debt,
                                    count: debts.count,
                                    total: debts.reduce(Decimal(0)) { $0 + $1.balance },
                                    accent: Theme.red
                                )
                            }
                        }

                        Text("Changing any of these redraws the route straight away. Nothing you have already recorded is affected.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            // Its own stack, so a row registered in `RootView` is not on a
            // different one and silently doing nothing.
            .navigationDestination(for: EntryKind.self) { EntryListView(kind: $0) }
            .navigationDestination(for: DebtRoute.self) { DebtDetailView(remoteID: $0.remoteID) }
            .navigationTitle("Adjust plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.lime)
                }
            }
        }
    }

    private func targetCard(_ planSettings: PlanSettings) -> some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Target period") { EmptyView() }

            GroupedCard {
                HStack {
                    Text("Clear everything within")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
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
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func sourceRow(kind: EntryKind, count: Int, total: Decimal, accent: Color) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 12) {
                Circle().fill(accent).frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.listTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(count) entries")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 8)

                Text(CurrencyFormat.string(total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
    }
}
