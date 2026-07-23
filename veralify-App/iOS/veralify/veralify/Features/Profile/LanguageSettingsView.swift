import SwiftUI

/// Lets the user override the app's display language independent of the
/// device's system language. Selecting a language updates every localized
/// string instantly, since `LocalizationManager` drives the environment's
/// `\.locale` / `\.layoutDirection` from the app root.
///
/// Deliberately built with a plain `ScrollView`/`VStack` instead of `List`:
/// `List` is backed by `UITableView`, and switching the app's
/// `layoutDirection` environment from `.rightToLeft` (Arabic) back to
/// `.leftToRight` can leave the table view's cell content mirrored — a
/// known UIKit RTL-transform-caching bug. Plain SwiftUI stacks re-layout
/// correctly every time, so this screen never gets stuck mirrored.
struct LanguageSettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                localization.language = language
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.nativeLabel)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if language.nativeLabel != language.label {
                                        Text(language.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if localization.language == language {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if language != AppLanguage.allCases.last {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .premiumCard()

                Text("Choose the language you'd like to use throughout Veralify.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle(Text("Language"))
        .navigationBarTitleDisplayMode(.inline)
        .hidesFloatingNavBar()
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
    .environmentObject(LocalizationManager.shared)
}

