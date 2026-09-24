import SwiftUI

/// Shown after signing in on a phone that has not been set up, while the
/// first sync looks for data the account already has.
///
/// A second phone, or a reinstall, should open onto the user's plan rather
/// than onto setup; setup would create a second, empty plan beside the real
/// one. So the choice waits for the first pull — and when there is no
/// connection, the user decides rather than the app guessing.
struct RestoringView: View {
    let failed: Bool
    let onRetry: () -> Void
    let onSetUpNew: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 18) {
                    if failed {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.yellow)
                            .frame(width: 62, height: 62)
                            .background(Theme.surface, in: .rect(cornerRadius: 18))
                            .accessibilityHidden(true)
                        Text("Couldn't reach your account")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("If you've used Veralify before, try again once you're online so your data comes back. If you're new, you can set up now.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.lime)
                        Text("Getting your data")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Checking your account for a plan you've already made.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 24)

                if failed {
                    VStack(spacing: 10) {
                        PrimaryButton(title: "Try again", action: onRetry)
                        SecondaryButton(title: "Set up as new", action: onSetUpNew)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

/// Shown instead of the app when the build has no backend settings. Only a
/// developer building without `Config/Backend.local.xcconfig` sees it, and the
/// message names the missing setting.
struct BackendMissingView: View {
    let problem: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.yellow)
                    Text("This build can't connect")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(problem)
                        .font(.callout.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }
}
