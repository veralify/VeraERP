import SwiftUI

struct HomeRootView: View {
    var body: some View {
        ShellEmptyStateView(
            title: "Your day starts here",
            message: "Today's progress, AI insights, streaks, live rooms, and community activity will appear here.",
            systemImage: "figure.run.circle.fill",
            ctaTitle: "Log food",
            ctaSystemImage: "plus.circle.fill"
        )
        .navigationTitle("Home")
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

struct TrackRootView: View {
    var body: some View {
        ShellEmptyStateView(
            title: "No meals logged yet",
            message: "Food, progress photos, goals, and trends will appear here once tracking ships in a later phase.",
            systemImage: "fork.knife.circle.fill",
            ctaTitle: "Open create",
            ctaSystemImage: "plus"
        )
        .navigationTitle("Track")
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

struct ConnectRootView: View {
    var body: some View {
        ShellEmptyStateView(
            title: "Your community is warming up",
            message: "Groups, live rooms, messages, coaches, and posts will appear here as Connect comes online.",
            systemImage: "person.3.sequence.fill",
            ctaTitle: "Create post",
            ctaSystemImage: "square.and.pencil"
        )
        .navigationTitle("Connect")
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

struct ShellEmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let ctaTitle: LocalizedStringKey
    let ctaSystemImage: String

    var body: some View {
        VStack(spacing: VeraTokens.Spacing._6) {
            Image(systemName: systemImage)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(AppTheme.premiumGradient)
                .accessibilityHidden(true)

            VStack(spacing: VeraTokens.Spacing._2) {
                Text(title)
                    .font(.system(size: VeraTokens.Typography.h3.size, weight: VeraTokens.Typography.h3.weight))
                    .foregroundStyle(VeraTokens.Colors.fg)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.system(size: VeraTokens.Typography.body.size, weight: VeraTokens.Typography.body.weight))
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(ctaTitle, systemImage: ctaSystemImage)
                .font(.headline)
                .foregroundStyle(VeraTokens.Colors.onPrimary)
                .padding(.horizontal, VeraTokens.Spacing._5)
                .padding(.vertical, VeraTokens.Spacing._3)
                .background(Capsule().fill(VeraTokens.Colors.primary))
        }
        .padding(VeraTokens.Spacing._6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.bottom, VeraTokens.SafeArea.bottomNavClearance)
    }
}
