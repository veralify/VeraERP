import Foundation
import SwiftUI

/// A daily objective.
///
/// Automatic quests are answered by the app's own data; manual ones are habits
/// only the user can confirm. Keeping the distinction explicit stops the app
/// from claiming to know something it does not.
struct Quest: Identifiable, Sendable {
    enum Kind: Sendable {
        /// Derived from data — the user cannot tick or untick it.
        case automatic
        /// A habit the user confirms.
        case manual
    }

    let id: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let icon: String
    let xp: Int
    let kind: Kind

    nonisolated(unsafe) static let all: [Quest] = [
        Quest(
            id: "log-entry",
            title: "Log today's money",
            detail: "Record at least one credit or debit.",
            icon: "square.and.pencil",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "in-surplus",
            title: "Stay in surplus",
            detail: "Keep income ahead of expenses and payments.",
            icon: "chart.line.uptrend.xyaxis",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "nothing-overdue",
            title: "Nothing due in 3 days",
            detail: "No payment creeping up on you.",
            icon: "calendar.badge.checkmark",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "review-plan",
            title: "Review your payoff plan",
            detail: "Open the plan and check where you stand.",
            icon: "target",
            xp: 25,
            kind: .manual
        )
    ]
}
