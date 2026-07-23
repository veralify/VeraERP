import Foundation
import SwiftUI

/// Languages Veralify ships with — mirrors the web app's language config so
/// behavior stays consistent across platforms.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case en, es, fr, de, it, ar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .en: return "English"
        case .es: return "Spanish"
        case .fr: return "French"
        case .de: return "German"
        case .it: return "Italian"
        case .ar: return "Arabic"
        }
    }

    var nativeLabel: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .ar: return "العربية"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .ar: return "🇵🇸"
        }
    }

    var direction: LayoutDirection {
        self == .ar ? .rightToLeft : .leftToRight
    }

    var locale: Locale { Locale(identifier: rawValue) }
}
