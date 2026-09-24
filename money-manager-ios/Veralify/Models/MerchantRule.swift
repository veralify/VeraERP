import Foundation
import SwiftData

/// A merchant the user filed by hand once, filed the same way next time
/// (`money_merchant_rules`).
///
/// Receipt reading applies these on the server before the AI is asked; the
/// phone keeps a synced copy so a correction made here reaches the web and
/// the next receipt without waiting for one to be read. Writing one when the
/// user corrects a category is receipt capture's job; sync only carries it.
@Model
final class MerchantRule {
    /// Normalised merchant name (contracts §4).
    var merchantKey: String
    var categoryKey: String
    /// `personal` or `business`, when the user also fixed the scope.
    var scope: String?
    /// How many times the rule has been confirmed.
    var hits: Int
    var createdAt: Date

    /// Sync bookkeeping — see `SyncedModel`.
    var id: UUID = UUID()
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?
    var needsPush: Bool = true

    init(
        merchantKey: String,
        categoryKey: String,
        scope: String? = nil,
        hits: Int = 1,
        createdAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.updatedAt = createdAt
        self.merchantKey = merchantKey
        self.categoryKey = categoryKey
        self.scope = scope
        self.hits = hits
        self.createdAt = createdAt
    }
}
