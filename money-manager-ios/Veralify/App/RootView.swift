import SwiftUI
import SwiftData

/// Decides between first-run setup and the app proper.
struct RootView: View {
    /// Survives a store reset, so a returning user is not sent back through
    /// setup after clearing data. Onboarding writes the flag only on completion.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                NavigationStack {
                    MainTabView()
                        .navigationDestination(for: EntryKind.self) { kind in
                            EntryListView(kind: kind)
                        }
                        .navigationDestination(for: DebtRoute.self) { route in
                            DebtDetailView(remoteID: route.remoteID)
                        }
                        .navigationDestination(for: SplitRoute.self) { _ in
                            QuickSplitView()
                        }
                        .navigationDestination(for: LedgerRoute.self) { _ in
                            TransactionsView()
                        }
                        .navigationDestination(for: CashFlowRoute.self) { _ in
                            CashFlowView()
                        }
                        .navigationDestination(for: WholePlanRoute.self) { _ in
                            CashFlowView(scope: .plan)
                        }
                        .navigationDestination(for: BudgetsRoute.self) { _ in
                            BudgetsView()
                        }
                        .navigationDestination(for: CategoryRoute.self) { route in
                            CategoryDetailView(route: route)
                        }
                }
            } else {
                OnboardingView { hasCompletedOnboarding = true }
            }
        }
        .tint(Theme.lime)
        // No colour-scheme lock: every token is adaptive, so the app follows
        // the system's light or dark appearance.
    }
}
