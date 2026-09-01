import Foundation
import SwiftUI

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

struct NutritionSnapshot: Codable, Hashable, Equatable {
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var sugarG: Double
    var sodiumMg: Double

    static let zero = NutritionSnapshot(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0)

    static func + (lhs: NutritionSnapshot, rhs: NutritionSnapshot) -> NutritionSnapshot {
        NutritionSnapshot(
            calories: lhs.calories + rhs.calories,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbsG: lhs.carbsG + rhs.carbsG,
            fatG: lhs.fatG + rhs.fatG,
            fiberG: lhs.fiberG + rhs.fiberG,
            sugarG: lhs.sugarG + rhs.sugarG,
            sodiumMg: lhs.sodiumMg + rhs.sodiumMg
        )
    }
}

struct FoodSearchResult: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarG: Double
    let sodiumMg: Double
    let servingSize: Double
    let servingUnit: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, name, brand, calories, source
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
    }
}

struct FoodServing: Identifiable, Decodable, Hashable {
    let id: String
    let foodID: String
    let label: String
    let grams: Double

    enum CodingKeys: String, CodingKey {
        case id, label, grams
        case foodID = "food_id"
    }
}

struct FoodLogItem: Identifiable, Decodable, Hashable {
    let id: String
    let foodLogID: String
    let foodID: String?
    var name: String
    var quantity: Double
    var unit: String
    var grams: Double?
    var nutrition: NutritionSnapshot
    var confidence: Double?
    var aiEstimated: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, grams, calories, confidence
        case foodLogID = "food_log_id"
        case foodID = "food_id"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case aiEstimated = "ai_estimated"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        foodLogID = try c.decode(String.self, forKey: .foodLogID)
        foodID = try c.decodeIfPresent(String.self, forKey: .foodID)
        name = try c.decode(String.self, forKey: .name)
        quantity = try c.decode(Double.self, forKey: .quantity)
        unit = try c.decode(String.self, forKey: .unit)
        grams = try c.decodeIfPresent(Double.self, forKey: .grams)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        aiEstimated = try c.decodeIfPresent(Bool.self, forKey: .aiEstimated) ?? false
        nutrition = NutritionSnapshot(
            calories: try c.decode(Double.self, forKey: .calories),
            proteinG: try c.decodeIfPresent(Double.self, forKey: .proteinG) ?? 0,
            carbsG: try c.decodeIfPresent(Double.self, forKey: .carbsG) ?? 0,
            fatG: try c.decodeIfPresent(Double.self, forKey: .fatG) ?? 0,
            fiberG: try c.decodeIfPresent(Double.self, forKey: .fiberG) ?? 0,
            sugarG: try c.decodeIfPresent(Double.self, forKey: .sugarG) ?? 0,
            sodiumMg: try c.decodeIfPresent(Double.self, forKey: .sodiumMg) ?? 0
        )
    }

    init(id: String = UUID().uuidString, foodLogID: String, foodID: String?, name: String, quantity: Double, unit: String, grams: Double?, nutrition: NutritionSnapshot, confidence: Double?, aiEstimated: Bool) {
        self.id = id
        self.foodLogID = foodLogID
        self.foodID = foodID
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.grams = grams
        self.nutrition = nutrition
        self.confidence = confidence
        self.aiEstimated = aiEstimated
    }
}

struct FoodLog: Identifiable, Decodable, Hashable {
    let id: String
    let mealGroupID: String?
    let loggedAt: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case mealGroupID = "meal_group_id"
        case loggedAt = "logged_at"
    }
}

struct MealGroup: Identifiable, Decodable, Hashable {
    let id: String
    let mealType: MealType
    let name: String
    let loggedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case mealType = "meal_type"
        case loggedAt = "logged_at"
    }
}

struct MealSection: Identifiable, Hashable {
    let mealType: MealType
    var groups: [MealGroup]
    var logs: [FoodLog]
    var itemsByLogID: [String: [FoodLogItem]]

    var id: String { mealType.rawValue }
    var items: [FoodLogItem] { logs.flatMap { itemsByLogID[$0.id] ?? [] } }
    var totals: NutritionSnapshot { items.reduce(.zero) { $0 + $1.nutrition } }
}

struct TrackDaySnapshot {
    let date: Date
    let targets: [HomeGoalTarget]
    let meals: [MealSection]

    var totals: NutritionSnapshot { meals.reduce(.zero) { $0 + $1.totals } }
    func target(_ metric: String) -> Double? { targets.first { $0.metric == metric }?.targetValue }
}

enum FoodProvenance: String, Codable, Hashable {
    case `internal`
    case external
    case aiEstimatePendingVerification = "ai_estimate_pending_verification"

    var title: String {
        switch self {
        case .internal: return "Internal"
        case .external: return "External"
        case .aiEstimatePendingVerification: return "Needs verification"
        }
    }
}

struct FoodAnalysisCandidate: Identifiable, Decodable, Hashable {
    var id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let grams: Double
    let nutrition: NutritionSnapshot
    let confidence: Double
    let assumptions: [String]
    let provenance: FoodProvenance
    let foodID: String?

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit, grams, calories, confidence, assumptions, provenance
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case foodID = "food_id"
    }

    init(name: String, quantity: Double, unit: String, grams: Double, nutrition: NutritionSnapshot, confidence: Double, assumptions: [String], provenance: FoodProvenance, foodID: String?) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.grams = grams
        self.nutrition = nutrition
        self.confidence = confidence
        self.assumptions = assumptions
        self.provenance = provenance
        self.foodID = foodID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        quantity = try c.decodeIfPresent(Double.self, forKey: .quantity) ?? 1
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? "serving"
        grams = try c.decodeIfPresent(Double.self, forKey: .grams) ?? 0
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        assumptions = try c.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        provenance = try c.decodeIfPresent(FoodProvenance.self, forKey: .provenance) ?? .aiEstimatePendingVerification
        foodID = try c.decodeIfPresent(String.self, forKey: .foodID)
        nutrition = NutritionSnapshot(
            calories: try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0,
            proteinG: try c.decodeIfPresent(Double.self, forKey: .proteinG) ?? 0,
            carbsG: try c.decodeIfPresent(Double.self, forKey: .carbsG) ?? 0,
            fatG: try c.decodeIfPresent(Double.self, forKey: .fatG) ?? 0,
            fiberG: try c.decodeIfPresent(Double.self, forKey: .fiberG) ?? 0,
            sugarG: try c.decodeIfPresent(Double.self, forKey: .sugarG) ?? 0,
            sodiumMg: try c.decodeIfPresent(Double.self, forKey: .sodiumMg) ?? 0
        )
    }
}

struct FoodAnalysisResponse: Decodable, Hashable {
    let items: [FoodAnalysisCandidate]
    let overallConfidence: Double
    let requiresConfirmation: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case overallConfidence = "overall_confidence"
        case requiresConfirmation = "requires_confirmation"
    }
}
