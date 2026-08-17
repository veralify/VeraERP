import Foundation

/// Persists logged food entries and nutrition goals locally, mirroring the
/// pattern used by `LocalOrderStore` for eSIM order history. A dedicated
/// backend sync can replace this later without changing call sites.
final class FoodLogStore {
    static let shared = FoodLogStore()
    private init() {}

    private let entriesKey = "com.veralify.calories.entries"
    private let goalsKey = "com.veralify.calories.goals"

    // MARK: - Entries

    func allEntries() -> [FoodEntry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return [] }
        return (try? JSONDecoder().decode([FoodEntry].self, from: data)) ?? []
    }

    /// Entries logged on the given calendar day, most recent first.
    func entries(on day: Date, calendar: Calendar = .current) -> [FoodEntry] {
        allEntries()
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    @discardableResult
    func save(_ entry: FoodEntry) -> [FoodEntry] {
        var entries = allEntries()
        entries.insert(entry, at: 0)
        persist(entries)
        return entries
    }

    func delete(_ entry: FoodEntry) {
        var entries = allEntries()
        entries.removeAll { $0.id == entry.id }
        persist(entries)
    }

    private func persist(_ entries: [FoodEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    // MARK: - Goals

    func goals() -> NutritionGoals {
        guard
            let data = UserDefaults.standard.data(forKey: goalsKey),
            let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data)
        else {
            return .default
        }
        return goals
    }

    func saveGoals(_ goals: NutritionGoals) {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: goalsKey)
        }
    }
}
