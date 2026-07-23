import Foundation
import SwiftUI
import Combine

/// Single source of truth for the app's in-app language override. Persists
/// the user's choice and is applied at the app root via
/// `.environment(\.locale, ...)` / `.environment(\.layoutDirection, ...)`,
/// so every `Text` / String Catalog lookup updates instantly — no relaunch
/// required. (System-rendered UI like the keyboard or OS alerts still
/// follows the device's own language, which is expected platform behavior.)
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "com.veralify.selectedLanguage"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
            return
        }

        // First launch: default to the device's preferred language if we
        // ship it, otherwise fall back to English.
        let preferredCode = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
        language = preferredCode.flatMap(AppLanguage.init(rawValue:)) ?? .en
    }
}
