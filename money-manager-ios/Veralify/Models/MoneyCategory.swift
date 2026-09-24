import Foundation
import SwiftData

/// One of the account's spending categories (`money_categories`).
///
/// Shared by the phone, the web dashboard and receipt reading, which must
/// file a receipt under one of these keys rather than invent one. `key` is
/// the stable identifier every transaction, budget and rule refers to; `name`
/// is only what the web shows until it localises by key, so the phone draws
/// its own localised title for the default keys.
@Model
final class MoneyCategory {
    var key: String
    var name: String
    /// An SF Symbol name.
    var icon: String?
    /// A hex colour, when the user picked one on the web.
    var color: String?
    /// `expense` or `income`.
    var kind: String
    var sortOrder: Int
    /// Hidden from pickers but kept, so old entries still resolve.
    var archived: Bool
    var createdAt: Date

    /// Sync bookkeeping — see `SyncedModel`.
    var id: UUID = UUID()
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?
    var needsPush: Bool = true

    init(
        key: String,
        name: String,
        icon: String? = nil,
        color: String? = nil,
        kind: String = "expense",
        sortOrder: Int = 0,
        archived: Bool = false,
        createdAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.updatedAt = createdAt
        self.key = key
        self.name = name
        self.icon = icon
        self.color = color
        self.kind = kind
        self.sortOrder = sortOrder
        self.archived = archived
        self.createdAt = createdAt
    }
}
