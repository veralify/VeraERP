import SwiftUI

/// The shared category keys (docs/RECEIPTS_CONTRACTS.md §3) with their
/// display names and icons on this phone.
///
/// The key is what is stored and synced; the name is only ever shown. That is
/// why the names live here, localised, and never travel: "Eating out" on an
/// English phone and "Mangiare fuori" on an Italian one are the same
/// `eating_out` in the budget, the rules table and the accounting export.
enum ReceiptCategories {

    /// Every key, in the order the picker offers them.
    static let keys: [String] = [
        "groceries", "eating_out", "transport", "fuel", "housing", "utilities",
        "shopping", "health", "entertainment", "travel", "subscriptions",
        "office_supplies", "software", "professional_services", "education",
        "gifts_donations", "fees_charges", "other"
    ]

    /// The keys to offer: the standard set, plus the receipt's own key if the
    /// user has a custom category the gateway picked from.
    static func options(including key: String?) -> [String] {
        guard let key, !keys.contains(key) else { return keys }
        return keys + [key]
    }

    static func title(for key: String) -> String {
        switch key {
        case "groceries": String(localized: "Groceries")
        case "eating_out": String(localized: "Eating out")
        case "transport": String(localized: "Transport")
        case "fuel": String(localized: "Fuel")
        case "housing": String(localized: "Housing")
        case "utilities": String(localized: "Utilities")
        case "shopping": String(localized: "Shopping")
        case "health": String(localized: "Health")
        case "entertainment": String(localized: "Entertainment")
        case "travel": String(localized: "Travel")
        case "subscriptions": String(localized: "Subscriptions")
        case "office_supplies": String(localized: "Office supplies")
        case "software": String(localized: "Software")
        case "professional_services": String(localized: "Professional services")
        case "education": String(localized: "Education")
        case "gifts_donations": String(localized: "Gifts and donations")
        case "fees_charges": String(localized: "Fees and charges")
        case "other": String(localized: "Other")
        // A custom key the user created elsewhere: show it readably rather
        // than as a snake_case identifier.
        default: key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func icon(for key: String) -> String {
        switch key {
        case "groceries": "cart.fill"
        case "eating_out": "fork.knife"
        case "transport": "tram.fill"
        case "fuel": "fuelpump.fill"
        case "housing": "house.fill"
        case "utilities": "bolt.fill"
        case "shopping": "bag.fill"
        case "health": "cross.case.fill"
        case "entertainment": "ticket.fill"
        case "travel": "airplane"
        case "subscriptions": "arrow.triangle.2.circlepath"
        case "office_supplies": "paperclip"
        case "software": "laptopcomputer"
        case "professional_services": "briefcase.fill"
        case "education": "graduationcap.fill"
        case "gifts_donations": "gift.fill"
        case "fees_charges": "building.columns.fill"
        default: "square.grid.2x2.fill"
        }
    }
}
