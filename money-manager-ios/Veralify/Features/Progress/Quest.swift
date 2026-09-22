import Foundation
import SwiftUI

/// A daily objective.
///
/// Automatic quests are answered by the app's own data; manual ones are habits
/// only the user can confirm. Keeping the distinction explicit stops the app
/// from claiming to know something it does not — and the detail sheet says
/// which kind a quest is, because "why can't I tick this one?" is otherwise a
/// fair question.
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
    /// What to actually go and do. The one-line `detail` says what the quest
    /// measures; this says how to satisfy it, which is what someone tapping a
    /// quest is asking.
    let how: LocalizedStringResource
    let icon: String
    let xp: Int
    let kind: Kind

    nonisolated(unsafe) static let all: [Quest] = [
        Quest(
            id: "log-entry",
            title: "Log today's money",
            detail: "Record at least one thing you spent or received.",
            how: "Tap Add — it is on every tab — type the amount, pick money in or money out, and swipe to confirm. One entry is enough to finish this.",
            icon: "square.and.pencil",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "in-surplus",
            title: "Stay in surplus",
            detail: "Keep income ahead of expenses and payments.",
            how: "Your income has to cover your expenses and your debt payments with something left over. Tap the big figure on Today to see the three numbers that make it up, and which one is eating the difference.",
            icon: "chart.line.uptrend.xyaxis",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "nothing-overdue",
            title: "Nothing due in 3 days",
            detail: "No payment creeping up on you.",
            how: "Nothing you owe falls due in the next three days. If something does, pay it — the bell in the corner lists what is coming — or correct its due date if it is wrong.",
            icon: "calendar.badge.checkmark",
            xp: 25,
            kind: .automatic
        ),
        Quest(
            id: "review-plan",
            title: "Review your payoff plan",
            detail: "Open the plan and check where you stand.",
            how: "Open the Plan tab and look at where you are on the route: what this month costs, what is left after it, and when the next debt clears. Then mark this done.",
            icon: "target",
            xp: 25,
            kind: .manual
        )
    ]
}
