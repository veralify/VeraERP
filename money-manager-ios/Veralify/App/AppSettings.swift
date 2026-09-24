import Foundation
import SwiftUI

/// User-chosen display settings: what currency amounts are shown in, and what
/// language the app speaks.
///
/// Held in `UserDefaults` rather than SwiftData because `CurrencyFormat` is a
/// free function called from roughly sixty places, including types that are not
/// views and have no model context to read from. `UserDefaults` is safe to read
/// from any thread, which those call sites need.
enum AppSettings {
    enum Key {
        static let currencyCode = "displayCurrencyCode"
        /// Apple's own key. Writing it is what actually switches the bundle's
        /// language, and it only takes effect on the next launch.
        static let appleLanguages = "AppleLanguages"
    }

    static let defaultCurrencyCode = "EUR"

    /// The language list this app itself chose, or nil when it follows the system.
    ///
    /// `UserDefaults.standard` falls back to the device-wide `AppleLanguages`, so
    /// reading it there always finds a value — "System" could never be detected,
    /// and the picker showed a specific language right after System was chosen.
    /// The app's own persistent domain only holds what `setLanguage` wrote.
    static var chosenLanguages: [String]? {
        guard let domain = Bundle.main.bundleIdentifier else { return nil }
        return UserDefaults.standard.persistentDomain(forName: domain)?[Key.appleLanguages] as? [String]
    }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: Key.currencyCode) ?? defaultCurrencyCode
    }

    /// The language the app will speak, which is the first entry iOS resolves
    /// against the bundle's localizations.
    static var languageCode: String {
        guard let stored = chosenLanguages?.first
        else { return Language.system.code }
        // iOS stores regional variants like "en-GB"; the catalog only has the
        // base languages.
        let base = String(stored.prefix(2))
        return Language.allCases.contains { $0.code == base } ? base : Language.system.code
    }

    static func setLanguage(_ language: Language) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: Key.appleLanguages)
        } else {
            UserDefaults.standard.set([language.code], forKey: Key.appleLanguages)
        }
    }
}

/// The languages the string catalog actually carries. Offering one it does not
/// have would silently fall back to English and look like a bug.
enum Language: String, CaseIterable, Identifiable, Hashable {
    case system, english, arabic, italian

    var id: String { rawValue }

    var code: String {
        switch self {
        case .system: Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        case .english: "en"
        case .arabic: "ar"
        case .italian: "it"
        }
    }

    /// Written in the language itself, as language pickers conventionally are —
    /// someone who has landed in the wrong language needs to recognise their
    /// own, not read the current one.
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "English"
        case .arabic: "العربية"
        case .italian: "Italiano"
        }
    }

    static var current: Language {
        guard AppSettings.chosenLanguages != nil else { return .system }
        return allCases.first { $0 != .system && $0.code == AppSettings.languageCode } ?? .system
    }
}

/// A currency the user can pick. Deliberately a short list rather than every ISO
/// code: a picker with 150 rows is worse than one with the handful that matter.
/// Not `Hashable`: `LocalizedStringResource` is not, and the picker identifies
/// rows by `code` anyway.
struct SupportedCurrency: Identifiable {
    let code: String
    let name: LocalizedStringResource

    var id: String { code }

    /// The symbol as the formatter will actually render it, so the picker
    /// cannot promise a symbol the amounts do not use.
    var symbol: String {
        Decimal(0).formatted(
            .currency(code: code).locale(Locale(identifier: "en_US")).precision(.fractionLength(0))
        )
        .replacingOccurrences(of: "0", with: "")
        .trimmingCharacters(in: .whitespaces)
    }

    static let all: [SupportedCurrency] = [
        SupportedCurrency(code: "EUR", name: "Euro"),
        SupportedCurrency(code: "USD", name: "US Dollar"),
        SupportedCurrency(code: "GBP", name: "British Pound"),
        SupportedCurrency(code: "CHF", name: "Swiss Franc"),
        SupportedCurrency(code: "EGP", name: "Egyptian Pound"),
        SupportedCurrency(code: "SAR", name: "Saudi Riyal"),
        SupportedCurrency(code: "AED", name: "UAE Dirham"),
        SupportedCurrency(code: "QAR", name: "Qatari Riyal"),
        SupportedCurrency(code: "KWD", name: "Kuwaiti Dinar"),
        SupportedCurrency(code: "TRY", name: "Turkish Lira"),
        SupportedCurrency(code: "MAD", name: "Moroccan Dirham"),
        SupportedCurrency(code: "TND", name: "Tunisian Dinar"),
        SupportedCurrency(code: "CAD", name: "Canadian Dollar"),
        SupportedCurrency(code: "AUD", name: "Australian Dollar"),
        SupportedCurrency(code: "SEK", name: "Swedish Krona"),
        SupportedCurrency(code: "NOK", name: "Norwegian Krone"),
        SupportedCurrency(code: "PLN", name: "Polish Zloty"),
        SupportedCurrency(code: "INR", name: "Indian Rupee"),
        SupportedCurrency(code: "JPY", name: "Japanese Yen")
    ]
}

/// Re-renders a screen when the display currency changes.
///
/// Amounts are formatted into plain `String`s by `CurrencyFormat`, which reads
/// the setting directly rather than through the environment. That keeps the
/// sixty-odd call sites simple, but it also means nothing in the view tree
/// depends on the setting, so nothing redraws when it changes — the dashboard
/// went on showing euros after the picker moved to pounds.
///
/// This puts that dependency at the screen level, which is the smallest place
/// it can live without threading a currency through every signature. Identity
/// changes, so the screen is rebuilt; that discards scroll position and local
/// state, which is acceptable for something the user changes once.
private struct CurrencyRedraw: ViewModifier {
    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode = AppSettings.defaultCurrencyCode

    func body(content: Content) -> some View {
        content.id(currencyCode)
    }
}

extension View {
    func redrawsOnCurrencyChange() -> some View { modifier(CurrencyRedraw()) }
}
