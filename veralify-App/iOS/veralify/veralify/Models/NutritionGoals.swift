import Foundation

/// Daily calorie/macro targets that drive the Calories tab's progress ring
/// and macro bars.
struct NutritionGoals: Codable, Hashable {
    var dailyCalories: Int
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double

    static let `default` = NutritionGoals(
        dailyCalories: 2200,
        proteinGrams: 150,
        carbGrams: 220,
        fatGrams: 70
    )
}
