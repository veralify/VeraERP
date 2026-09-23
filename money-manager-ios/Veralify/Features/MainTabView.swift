import SwiftUI
import SwiftData

/// Owns tab selection, the floating bar, the title and the add sheet, so all
/// four destinations share one persistent chrome.
///
/// The four are places, not modes: where you stand today, where the plan goes,
/// who owes what, and what is in your wallet. The ledger used to be the third
/// of them — it is now the day's entries on Today, with the full history one
/// push behind them, because a list of everything you ever typed is a reference,
/// not a destination you visit daily.
struct MainTabView: View {
    /// Every modal this screen can present.
    ///
    /// Stacking several `.sheet` modifiers on one view makes SwiftUI pick
    /// arbitrarily between them — it was presenting Alerts on launch. One
    /// `.sheet(item:)` driven by an enum is the supported way to offer a
    /// choice of destinations from the same view.
    private enum Destination: Identifiable {
        case quickAdd
        case alerts
        case account

        var id: String {
            switch self {
            case .quickAdd: "quick-add"
            case .alerts:   "alerts"
            case .account:  "account"
            }
        }
    }

    @State private var selection = 0
    @State private var destination: Destination?
    @State private var router = QuickAddRouter.shared

    private var title: LocalizedStringKey {
        switch selection {
        case 1:  "Board"
        case 2:  "Split"
        case 3:  "Wallet"
        default: "Today"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch selection {
                case 1:  BubbleBoardView()
                case 2:  FamilyView()
                case 3:  IDVaultView()
                default: DashboardView(onOpenPlan: { selection = 1 })
                }
            }
            // Scoped to the destinations rather than the whole screen: a
            // currency change must not tear down the sheet it was made in.
            .redrawsOnCurrencyChange()

            // One button, one meaning, on every tab: record money that moved.
            //
            // It used to branch three ways on the selected tab — the plan form,
            // a credit/debit fan-out, or a family sheet that silently became
            // "add a person" when the household was empty. A control that keeps
            // its position, label and colour has to keep its meaning too, and
            // everything it used to reach is now offered by the screen that owns
            // it: the entry lists have their own +, Family has its own.
            //
            // The fan-out is gone with it. The sheet it opened already carries
            // the same in/out switch in its header, so the extra step only asked
            // a question its own destination asks better.
            FloatingTabBar(selection: $selection, actionTitle: "Add", isActionActive: false) {
                destination = .quickAdd
            }
            .padding(.bottom, 8)
        }
        .fullScreenCover(item: Binding(
            get: { router.pendingFlash },
            set: { router.pendingFlash = $0 }
        )) { direction in
            SuccessFlash(
                title: direction == .credit ? "Money in recorded" : "Money out recorded",
                accent: direction.accent
            )
            .task {
                // The bloom takes ~0.5s and the label lands at 0.3s, so the
                // hold has to outlast both for the confirmation to be readable.
                // `.task` cancels with the view rather than firing into nothing.
                try? await Task.sleep(for: .seconds(1.5))
                router.pendingFlash = nil
            }
        }
        // On the shell rather than on the tab's content: attached to the
        // content it would be torn down and re-created on every tab change,
        // re-reading the whole notification queue each time.
        .background(ReminderTopUp())
        .sheet(item: $destination, content: sheet(for:))
        .sensoryFeedback(.selection, trigger: selection)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            ToolbarItem(placement: .topBarLeading) {
                AccountBadge { destination = .account }
            }
            ToolbarItem(placement: .topBarTrailing) {
                AlertsToolbarButton { destination = .alerts }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    @ViewBuilder
    private func sheet(for destination: Destination) -> some View {
        switch destination {
        case .quickAdd:
            QuickAddSheet()
                // Stops short of the top so the ledger stays visible behind it,
                // which keeps the sheet feeling like a step rather than a
                // different screen.
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Theme.background)
        case .alerts:
            AlertsView()
                .presentationBackground(Theme.background)
        case .account:
            AccountView()
                .presentationBackground(Theme.background)
        }
    }

}

/// Shared empty state, so every screen says the same thing the same way.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.lime)
                .frame(width: 62, height: 62)
                .background(Theme.lime.opacity(0.13), in: .circle)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}
