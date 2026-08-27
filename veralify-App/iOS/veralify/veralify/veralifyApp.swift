import SwiftUI

@main
struct veralifyApp: App {
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var filmViewModel = FilmViewModel()

    init() {
        Task { @MainActor in
            StoreKitManager.shared.startTransactionListener()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
                .environmentObject(filmViewModel)
                .environment(\.locale, localization.language.locale)
                .environment(\.layoutDirection, localization.language.direction)
                .onOpenURL { url in
                    if let deepLink = FilmInviteDeepLink.parse(url: url) {
                        filmViewModel.pendingInviteToken = deepLink.token
                        filmViewModel.isShowingJoinSheet = true
                    }
                }
        }
    }
}
