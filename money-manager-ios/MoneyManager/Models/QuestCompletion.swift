import Foundation
import SwiftData

/// A quest ticked off on a given day.
///
/// Only *manual* quests are stored. Automatic ones are re-derived from the data
/// each time, so they can never drift out of step with reality — a quest that
/// claims you stayed in surplus while the dashboard shows a deficit would
/// destroy trust in both.
@Model
final class QuestCompletion {
    var questID: String
    /// Normalised to the start of the day it was completed.
    var day: Date
    var xp: Int

    init(questID: String, day: Date, xp: Int) {
        self.questID = questID
        self.day = day
        self.xp = xp
    }
}
