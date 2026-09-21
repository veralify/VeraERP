import SwiftUI

/// Owns tab selection, the floating bar, the title and the add sheet, so all
/// four destinations share one persistent chrome.
struct MainTabView: View {
    /// Every modal this screen can present.
    ///
    /// Stacking several `.sheet` modifiers on one view makes SwiftUI pick
    /// arbitrarily between them — it was presenting Alerts on launch. One
    /// `.sheet(item:)` driven by an enum is the supported way to offer a
    /// choice of destinations from the same view.
    private enum Destination: Identifiable {
        case planEntry
        case quickAdd(EntryDirection)
        case alerts
        case account

        var id: String {
            switch self {
            case .planEntry:               "plan"
            case .quickAdd(let direction): "quick-\(direction.rawValue)"
            case .alerts:                  "alerts"
            case .account:                 "account"
            }
        }
    }

    @State private var selection = 0
    @State private var destination: Destination?
    @State private var isChoosingDirection = false
    @State private var router = QuickAddRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLedger: Bool { selection == 2 }

    private var title: LocalizedStringKey {
        switch selection {
        case 1:  "Roadmap"
        case 2:  "Entries"
        case 3:  "Analytics"
        default: "Dashboard"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch selection {
                case 1:  JourneyView()
                case 2:  TransactionsView()
                case 3:  AnalyticsView()
                default: DashboardView { selection = 1 }
                }
            }
            // Scoped to the destinations rather than the whole screen: a
            // currency change must not tear down the sheet it was made in.
            .redrawsOnCurrencyChange()

            // Dim behind the fan-out so the two choices read as a modal step.
            if isChoosingDirection {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { isChoosingDirection = false }
            }

            VStack(spacing: 12) {
                if isChoosingDirection {
                    directionChoices
                }

                FloatingTabBar(selection: $selection, actionTitle: "Add", isActionActive: isChoosingDirection) {
                    // On the ledger the action is a transaction, which has two
                    // sides; everywhere else it adds to the plan.
                    if isLedger {
                        withAnimation(reduceMotion ? .smooth(duration: 0.2) : .bouncy(duration: 0.34)) {
                            isChoosingDirection.toggle()
                        }
                    } else {
                        destination = .planEntry
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .fullScreenCover(item: Binding(
            get: { router.pendingFlash },
            set: { router.pendingFlash = $0 }
        )) { direction in
            SuccessFlash(
                title: direction == .credit ? "Credit added" : "Debit added",
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
        .sheet(item: $destination, content: sheet(for:))
        .onChange(of: selection) { _, _ in
            withAnimation(.smooth(duration: 0.2)) { isChoosingDirection = false }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .sensoryFeedback(.impact(weight: .medium), trigger: isChoosingDirection) { _, open in open }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { destination = .account } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Account")
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
        case .planEntry:
            EntryFormSheet(mode: .add(nil))
                .presentationBackground(Theme.background)
        case .quickAdd(let direction):
            QuickAddSheet(scope: QuickAddRouter.shared.scope, initialDirection: direction)
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

    private var directionChoices: some View {
        VStack(spacing: 10) {
            ForEach(EntryDirection.allCases) { option in
                Button {
                    isChoosingDirection = false
                    destination = .quickAdd(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 38, height: 38)
                            .background(option.accent, in: .circle)
                        Text(option.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(width: 210)
                    .background(Theme.surface, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.86, anchor: .bottom))
                )
            }
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
