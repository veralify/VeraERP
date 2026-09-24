import SwiftUI
import SwiftData

/// Decides between sign-in, first-run setup and the app proper.
///
/// An account comes first (owner decision: all data syncs), then setup — but
/// only on a phone where the account has no plan yet, which is not known until
/// the first sync has pulled.
struct RootView: View {
    /// Survives a store reset, so a returning user is not sent back through
    /// setup after clearing data. Onboarding writes the flag only on completion.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(AuthModel.self) private var auth
    @Environment(SyncEngine.self) private var sync
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    private enum Restore: Equatable {
        /// Not looked yet for this sign-in.
        case pending
        case running
        /// The first sync could not reach the server.
        case failed
        /// Looked, and the account had no plan: set up.
        case done
    }

    @State private var restore: Restore = .pending

    var body: some View {
        Group {
            switch auth.state {
            case .unconfigured(let problem):
                BackendMissingView(problem: problem)
            case .signedOut:
                SignInView()
            case .signedIn:
                if hasCompletedOnboarding {
                    mainApp
                } else if restore == .done {
                    OnboardingView { hasCompletedOnboarding = true }
                } else {
                    RestoringView(
                        failed: restore == .failed,
                        onRetry: { Task { await restoreAccount() } },
                        onSetUpNew: { restore = .done }
                    )
                }
            }
        }
        .tint(Theme.lime)
        // The design is dark-only: its accents are light, saturated tones that
        // carry near-black text and have no light-mode counterpart yet.
        .preferredColorScheme(.dark)
        .task { auth.start() }
        .onChange(of: auth.userID, initial: true) { _, userID in
            connectSync(to: userID)
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app is when another device's changes are
            // most likely waiting.
            if phase == .active, auth.userID != nil, hasCompletedOnboarding {
                Task { await sync.sync() }
            }
        }
    }

    private var mainApp: some View {
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
    }

    private func connectSync(to userID: UUID?) {
        guard let userID, let backend = auth.backend else {
            sync.connect(remote: nil, userID: nil)
            restore = .pending
            return
        }
        sync.connect(remote: SupabaseSyncRemote(client: backend.client), userID: userID)
        Task { await restoreAccount() }
    }

    /// The first sync after signing in. On a phone already set up it is an
    /// ordinary sync (which also uploads anything made before accounts
    /// existed); otherwise it decides whether setup is needed at all.
    private func restoreAccount() async {
        if hasCompletedOnboarding {
            // Already looked: if setup is ever asked for again on this
            // sign-in ("Delete all data and start over"), it goes straight to it.
            restore = .done
            await sync.sync()
            return
        }
        restore = .running
        await sync.sync()
        if hasPlan() {
            hasCompletedOnboarding = true
            restore = .done
        } else if sync.status == .offline || sync.lastSyncedAt == nil {
            restore = .failed
        } else {
            restore = .done
        }
    }

    /// Whether the store holds a plan — pulled from the account, or made on
    /// this phone before sign-in existed.
    private func hasPlan() -> Bool {
        let counts = [
            (try? context.fetchCount(FetchDescriptor<IncomeSource>())) ?? 0,
            (try? context.fetchCount(FetchDescriptor<ExpenseItem>())) ?? 0,
            (try? context.fetchCount(FetchDescriptor<DebtRecord>())) ?? 0,
            (try? context.fetchCount(FetchDescriptor<PlanSettings>())) ?? 0
        ]
        return counts.contains { $0 > 0 }
    }
}
