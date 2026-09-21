import Foundation
import SwiftData
import SwiftUI
import MoneyManagerCore

/// Someone the household's costs are shared with.
@Model
final class FamilyMember {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Index into `FamilyMember.palette`, so a member keeps their colour even if
    /// the palette is reordered later.
    var colorIndex: Int
    var emoji: String
    /// The account holder. Exactly one, created with the first member.
    var isMe: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int = 0,
        emoji: String = "🙂",
        isMe: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.emoji = emoji
        self.isMe = isMe
        self.createdAt = createdAt
    }

    static let palette: [Color] = [
        Theme.lime, Theme.blue, Theme.yellow, Theme.red, Theme.green
    ]

    var color: Color { Self.palette[abs(colorIndex) % Self.palette.count] }
}

/// A cost one person paid and the household shares.
///
/// Deliberately separate from `ExpenseItem`, which is the recurring plan that
/// drives the payoff engine. These are one-off events with a payer and a split;
/// feeding them into the plan would count the same money twice.
@Model
final class FamilyExpense {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Decimal
    var date: Date
    var category: String
    /// `FamilyMember.id` of whoever actually paid.
    var paidByID: UUID
    /// `FamilyMember.id`s this is split between.
    var participantIDs: [UUID]
    /// Set only for an uneven split; `nil` means split equally.
    var customShares: [String: Decimal]?
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        date: Date = .now,
        category: String = "General",
        paidByID: UUID,
        participantIDs: [UUID],
        customShares: [String: Decimal]? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.paidByID = paidByID
        self.participantIDs = participantIDs
        self.customShares = customShares
        self.notes = notes
        self.createdAt = createdAt
    }

    /// The value type the split maths works on.
    var asSharedExpense: SharedExpense {
        let shares: [UUID: Decimal]
        if let customShares, !customShares.isEmpty {
            shares = Dictionary(
                uniqueKeysWithValues: customShares.compactMap { key, value in
                    UUID(uuidString: key).map { ($0, value) }
                }
            )
        } else {
            shares = FamilySplit.equalShares(of: amount, among: participantIDs)
        }
        return SharedExpense(id: id, amount: amount, paidBy: paidByID, shares: shares)
    }
}

/// Money one member actually handed another to square up.
@Model
final class FamilySettlement {
    @Attribute(.unique) var id: UUID
    var fromID: UUID
    var toID: UUID
    var amount: Decimal
    var date: Date

    init(id: UUID = UUID(), fromID: UUID, toID: UUID, amount: Decimal, date: Date = .now) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.amount = amount
        self.date = date
    }

    var asSettlement: Settlement {
        Settlement(from: fromID, to: toID, amount: amount)
    }
}

enum FamilyCategory {
    static let all = ["General", "Groceries", "Rent", "Bills", "Kids", "Health", "Travel", "Eating out"]

    /// A switch over literals, because `LocalizedStringKey(someString)` is a
    /// runtime value the string extractor cannot see — the chips would have
    /// stayed English in every language.
    static func title(for category: String) -> String {
        switch category {
        case "Groceries":   String(localized: "Groceries")
        case "Rent":        String(localized: "Rent")
        case "Bills":       String(localized: "Bills")
        case "Kids":        String(localized: "Kids")
        case "Health":      String(localized: "Health")
        case "Travel":      String(localized: "Travel")
        case "Eating out":  String(localized: "Eating out")
        default:            String(localized: "General")
        }
    }

    static func icon(for category: String) -> String {
        switch category {
        case "Groceries":   "cart.fill"
        case "Rent":        "house.fill"
        case "Bills":       "bolt.fill"
        case "Kids":        "figure.and.child.holdinghands"
        case "Health":      "cross.case.fill"
        case "Travel":      "airplane"
        case "Eating out":  "fork.knife"
        default:            "square.grid.2x2.fill"
        }
    }
}
