import Foundation

struct HomeGoal: Decodable, Identifiable {
    let id: String
    let title: String
    let type: String
    let targetValue: Double?
    let startingValue: Double?
    let unit: String?

    enum CodingKeys: String, CodingKey {
        case id, title, type, unit
        case targetValue = "target_value"
        case startingValue = "starting_value"
    }
}

struct HomeGoalTarget: Decodable, Identifiable {
    let id: String
    let metric: String
    let targetValue: Double
    let unit: String?

    enum CodingKeys: String, CodingKey {
        case id, metric, unit
        case targetValue = "target_value"
    }
}

struct DailyNutritionSummary: Decodable {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let mealCount: Int

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case mealCount = "meal_count"
    }
}

struct FoodLogRow: Decodable, Identifiable {
    let id: String
}

struct HomeSnapshot {
    let goal: HomeGoal?
    let targets: [HomeGoalTarget]
    let summary: DailyNutritionSummary?
    let foodLogCount: Int

    func target(_ metric: String) -> Double? {
        targets.first { $0.metric == metric }?.targetValue
    }
}

@MainActor
final class HomeRepository {
    private let supabase = SupabaseClient.shared

    func loadToday() async throws -> HomeSnapshot {
        let user = try await supabase.getUser()
        let goals: [HomeGoal] = try await supabase.select(
            from: "goals",
            columns: "id,title,type,target_value,starting_value,unit",
            filters: ["user_id": user.id, "status": "active"]
        )
        let goal = goals.first
        let targets: [HomeGoalTarget]
        if let goal {
            targets = try await supabase.select(
                from: "goal_targets",
                columns: "id,metric,target_value,unit",
                filters: ["goal_id": goal.id, "period": "daily"]
            )
        } else {
            targets = []
        }

        let today = Self.dayFormatter.string(from: Date())
        let summaries: [DailyNutritionSummary] = try await supabase.select(
            from: "daily_nutrition_summaries",
            columns: "calories,protein_g,carbs_g,fat_g,meal_count",
            filters: ["user_id": user.id, "date": today]
        )

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let logs: [FoodLogRow] = try await supabase.select(
            from: "food_logs",
            columns: "id",
            rawQueryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(user.id)"),
                URLQueryItem(name: "logged_at", value: "gte.\(Self.isoFormatter.string(from: start))"),
                URLQueryItem(name: "logged_at", value: "lt.\(Self.isoFormatter.string(from: end))")
            ]
        )

        return HomeSnapshot(goal: goal, targets: targets, summary: summaries.first, foodLogCount: logs.count)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()
}
