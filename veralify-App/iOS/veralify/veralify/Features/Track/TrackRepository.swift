import Foundation

private struct MealGroupPayload: Codable {
    let user_id: String
    let meal_type: MealType
    let name: String
    let logged_at: String
}

private struct FoodLogPayload: Codable {
    let user_id: String
    let meal_group_id: String?
    let logged_at: String
    let source: String?
    let notes: String?
}

private struct FoodLogItemUpdatePayload: Encodable {
    let quantity: Double
    let grams: Double?
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let fiber_g: Double
    let sugar_g: Double
    let sodium_mg: Double
}

@MainActor
final class TrackRepository {
    private let supabase = SupabaseClient.shared

    func loadDay(date: Date) async throws -> TrackDaySnapshot {
        let user = try await supabase.getUser()
        let bounds = Self.bounds(for: date)
        let groups: [MealGroup] = try await supabase.select(
            from: "meal_groups",
            columns: "id,meal_type,name,logged_at",
            rawQueryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(user.id)"),
                URLQueryItem(name: "logged_at", value: "gte.\(Self.isoFormatter.string(from: bounds.start))"),
                URLQueryItem(name: "logged_at", value: "lt.\(Self.isoFormatter.string(from: bounds.end))"),
                URLQueryItem(name: "order", value: "logged_at.asc")
            ]
        )
        let logs: [FoodLog] = try await supabase.select(
            from: "food_logs",
            columns: "id,meal_group_id,logged_at,notes",
            rawQueryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(user.id)"),
                URLQueryItem(name: "logged_at", value: "gte.\(Self.isoFormatter.string(from: bounds.start))"),
                URLQueryItem(name: "logged_at", value: "lt.\(Self.isoFormatter.string(from: bounds.end))"),
                URLQueryItem(name: "order", value: "logged_at.asc")
            ]
        )
        let items: [FoodLogItem]
        if logs.isEmpty {
            items = []
        } else {
            let ids = logs.map(\.id).joined(separator: ",")
            items = try await supabase.select(
                from: "food_log_items",
                columns: "id,food_log_id,food_id,name,quantity,unit,grams,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,confidence,ai_estimated",
                rawQueryItems: [URLQueryItem(name: "food_log_id", value: "in.(\(ids))")]
            )
        }
        let targets = try await loadTargets(userID: user.id)
        return TrackDaySnapshot(date: date, targets: targets, meals: MealGrouping.sections(groups: groups, logs: logs, items: items))
    }

    func searchFoods(query: String) async throws -> [FoodSearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return try await supabase.select(
            from: "foods",
            columns: "id,name,brand,calories,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,serving_size,serving_unit,source",
            rawQueryItems: [
                URLQueryItem(name: "name", value: "ilike.*\(term)*"),
                URLQueryItem(name: "order", value: "name.asc"),
                URLQueryItem(name: "limit", value: "25")
            ]
        )
    }

    func servings(for foodID: String) async throws -> [FoodServing] {
        try await supabase.select(
            from: "food_servings",
            columns: "id,food_id,label,grams",
            filters: ["food_id": foodID]
        )
    }

    @discardableResult
    func log(food: FoodSearchResult, mealType: MealType, date: Date, servingGrams: Double, quantity: Double) async throws -> FoodLogItem {
        let log = try await createFoodLog(mealType: mealType, date: date, source: "manual", notes: nil)
        let payload = FoodLogSnapshotBuilder.payload(logID: log.id, food: food, servingGrams: servingGrams, quantity: quantity)
        return try await supabase.insert(into: "food_log_items", data: payload, returning: FoodLogItem.self)
    }

    @discardableResult
    func log(candidate: FoodAnalysisCandidate, mealType: MealType, date: Date) async throws -> FoodLogItem {
        let log = try await createFoodLog(mealType: mealType, date: date, source: "ai", notes: candidate.assumptions.joined(separator: "; "))
        let payload = FoodLogSnapshotBuilder.payload(logID: log.id, candidate: candidate)
        return try await supabase.insert(into: "food_log_items", data: payload, returning: FoodLogItem.self)
    }

    @discardableResult
    func update(item: FoodLogItem, using food: FoodSearchResult, servingGrams: Double, quantity: Double) async throws -> FoodLogItem {
        let full = FoodLogSnapshotBuilder.payload(logID: item.foodLogID, food: food, servingGrams: servingGrams, quantity: quantity)
        let payload = FoodLogItemUpdatePayload(
            quantity: full.quantity,
            grams: full.grams,
            calories: full.calories,
            protein_g: full.protein_g,
            carbs_g: full.carbs_g,
            fat_g: full.fat_g,
            fiber_g: full.fiber_g,
            sugar_g: full.sugar_g,
            sodium_mg: full.sodium_mg
        )
        return try await supabase.update(table: "food_log_items", data: payload, returning: FoodLogItem.self, filters: ["id": item.id])
    }

    func delete(item: FoodLogItem) async throws {
        try await supabase.delete(from: "food_log_items", filters: ["id": item.id])
    }

    private func createFoodLog(mealType: MealType, date: Date, source: String, notes: String?) async throws -> FoodLog {
        let user = try await supabase.getUser()
        let group = try await mealGroup(userID: user.id, mealType: mealType, date: date)
        let payload = FoodLogPayload(user_id: user.id, meal_group_id: group.id, logged_at: Self.isoFormatter.string(from: date), source: source, notes: notes)
        return try await supabase.insert(into: "food_logs", data: payload, returning: FoodLog.self)
    }

    private func mealGroup(userID: String, mealType: MealType, date: Date) async throws -> MealGroup {
        let bounds = Self.bounds(for: date)
        let rows: [MealGroup] = try await supabase.select(
            from: "meal_groups",
            columns: "id,meal_type,name,logged_at",
            rawQueryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "meal_type", value: "eq.\(mealType.rawValue)"),
                URLQueryItem(name: "logged_at", value: "gte.\(Self.isoFormatter.string(from: bounds.start))"),
                URLQueryItem(name: "logged_at", value: "lt.\(Self.isoFormatter.string(from: bounds.end))"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        if let existing = rows.first { return existing }
        let payload = MealGroupPayload(user_id: userID, meal_type: mealType, name: mealType.title, logged_at: Self.isoFormatter.string(from: date))
        return try await supabase.insert(into: "meal_groups", data: payload, returning: MealGroup.self)
    }

    private func loadTargets(userID: String) async throws -> [HomeGoalTarget] {
        let goals: [HomeGoal] = try await supabase.select(
            from: "goals",
            columns: "id,title,type,target_value,starting_value,unit",
            filters: ["user_id": userID, "status": "active"]
        )
        guard let goal = goals.first else { return [] }
        return try await supabase.select(
            from: "goal_targets",
            columns: "id,metric,target_value,unit",
            filters: ["goal_id": goal.id, "period": "daily"]
        )
    }

    private static func bounds(for date: Date) -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: date)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date)
    }

    private static let isoFormatter = ISO8601DateFormatter()
}
