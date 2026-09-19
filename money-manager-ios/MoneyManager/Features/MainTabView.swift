import SwiftUI

/// Owns tab selection, the floating bar, the title and the add sheet, so all
/// four destinations share one persistent chrome.
struct MainTabView: View {
    @State private var selection = 0
    @State private var isAddingEntry = false

    private var title: LocalizedStringKey {
        switch selection {
        case 1:  "Analytics"
        case 2:  "Alerts"
        case 3:  "Account"
        default: "Dashboard"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch selection {
                case 1:  AnalyticsView()
                case 2:  AlertsView()
                case 3:  AccountView()
                default: DashboardView()
                }
            }

            FloatingTabBar(selection: $selection, actionTitle: "Add") {
                isAddingEntry = true
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $isAddingEntry) {
            // nil kind: the dock is a general "add", so the user picks.
            EntryFormSheet(mode: .add(nil))
                .presentationBackground(Theme.background)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
