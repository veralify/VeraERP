import Foundation

/// A category every account starts with (contracts §3).
public struct DefaultCategory: Sendable, Equatable {
    public let key: String
    /// English name stored on the server row. Clients localise by key; this is
    /// what the web shows until it does, and what a reader of the table sees.
    public let name: String
    public let icon: String
    public let sortOrder: Int
}

public enum CategoryKeys {
    /// The seed list, in display order. The order and keys are the contract;
    /// the server seeds the same list (migration 20260925100000).
    public static let defaults: [DefaultCategory] = [
        ("groceries", "Groceries", "cart.fill"),
        ("eating_out", "Eating out", "fork.knife"),
        ("transport", "Transport", "tram.fill"),
        ("fuel", "Fuel", "fuelpump.fill"),
        ("housing", "Housing", "house.fill"),
        ("utilities", "Utilities", "bolt.fill"),
        ("shopping", "Shopping", "bag.fill"),
        ("health", "Health", "cross.case.fill"),
        ("entertainment", "Entertainment", "film.fill"),
        ("travel", "Travel", "airplane"),
        ("subscriptions", "Subscriptions", "repeat"),
        ("office_supplies", "Office supplies", "paperclip"),
        ("software", "Software", "laptopcomputer"),
        ("professional_services", "Professional services", "briefcase.fill"),
        ("education", "Education", "graduationcap.fill"),
        ("gifts_donations", "Gifts & donations", "gift.fill"),
        ("fees_charges", "Fees & charges", "percent"),
        ("other", "Other", "square.grid.2x2.fill")
    ].enumerated().map { index, item in
        DefaultCategory(key: item.0, name: item.1, icon: item.2, sortOrder: index)
    }

    public static let defaultKeys: Set<String> = Set(defaults.map(\.key))

    /// The app's original preset chips, and the key each one is filed under.
    /// Entries stored under these names are rewritten to their keys once, on
    /// the first launch with sync (`SyncMigration`); the mapping stays for
    /// anything written by an older build since.
    public static let presetKeys: [String: String] = [
        "General": "other",
        "Tools": "office_supplies",
        "Food": "groceries",
        "Transport": "transport",
        "Bills": "utilities",
        "Shopping": "shopping",
        "Health": "health"
    ]

    /// Category names written before keys existed, matched without regard to
    /// case: the presets above plus the web form's old default. The web
    /// dashboard maps stored values on read with the same table
    /// (`src/lib/money/spending.ts`), so an entry groups the same on both.
    public static let legacyKeys: [String: String] = [
        "general": "other",
        "tools": "office_supplies",
        "food": "groceries",
        "transport": "transport",
        "bills": "utilities",
        "shopping": "shopping",
        "health": "health",
        "uncategorized": "other"
    ]

    /// A valid key: what `money_categories.key` accepts.
    public static func isValidKey(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 40 && text.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_"
        }
    }

    /// The key a category stored on the phone is filed under — and what it is
    /// rewritten to by the one-time migration.
    ///
    /// A preset or legacy name maps by the tables above; something that
    /// already is a key (a category that arrived from the server, or that
    /// receipt capture filed) stays as it is; anything else the user typed
    /// becomes a slug of itself, so "Gym" syncs as `gym` rather than being
    /// flattened into `other`. (The web keeps unknown free text verbatim on
    /// read because it cannot rewrite old rows; the phone can, and a slug is a
    /// valid key where free text is not.)
    public static func key(forLocal category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "other" }
        if let key = presetKeys[trimmed] { return key }
        if defaultKeys.contains(trimmed) { return trimmed }
        if let key = legacyKeys[trimmed.lowercased()] { return key }
        if isValidKey(trimmed) { return trimmed }
        let slug = slug(trimmed)
        return slug.isEmpty ? "other" : slug
    }

    /// Lower-case ASCII letters, digits and single underscores, at most 40
    /// characters: "Café & Bar" → "cafe_bar".
    public static func slug(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var result = ""
        var pendingSeparator = false
        for scalar in folded.unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                if pendingSeparator && !result.isEmpty { result.append("_") }
                result.unicodeScalars.append(scalar)
                pendingSeparator = false
            } else {
                pendingSeparator = true
            }
        }
        return String(result.prefix(40)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
