import Foundation

struct FoodLogItemPayload: Encodable, Equatable {
    let food_log_id: String
    let food_id: String?
    let name: String
    let quantity: Double
    let unit: String
    let grams: Double?
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
    let fiber_g: Double
    let sugar_g: Double
    let sodium_mg: Double
    let confidence: Double?
    let ai_estimated: Bool
}

enum FoodLogSnapshotBuilder {
    static func payload(logID: String, food: FoodSearchResult, servingGrams: Double, quantity: Double) -> FoodLogItemPayload {
        let factor = (servingGrams * quantity) / max(food.servingSize, 0.0001)
        return FoodLogItemPayload(
            food_log_id: logID,
            food_id: food.id,
            name: food.name,
            quantity: quantity,
            unit: food.servingUnit,
            grams: servingGrams * quantity,
            calories: food.calories * factor,
            protein_g: food.proteinG * factor,
            carbs_g: food.carbsG * factor,
            fat_g: food.fatG * factor,
            fiber_g: food.fiberG * factor,
            sugar_g: food.sugarG * factor,
            sodium_mg: food.sodiumMg * factor,
            confidence: nil,
            ai_estimated: false
        )
    }

    static func payload(logID: String, candidate: FoodAnalysisCandidate) -> FoodLogItemPayload {
        FoodLogItemPayload(
            food_log_id: logID,
            food_id: candidate.foodID,
            name: candidate.name,
            quantity: candidate.quantity,
            unit: candidate.unit,
            grams: candidate.grams,
            calories: candidate.nutrition.calories,
            protein_g: candidate.nutrition.proteinG,
            carbs_g: candidate.nutrition.carbsG,
            fat_g: candidate.nutrition.fatG,
            fiber_g: candidate.nutrition.fiberG,
            sugar_g: candidate.nutrition.sugarG,
            sodium_mg: candidate.nutrition.sodiumMg,
            confidence: candidate.confidence,
            ai_estimated: candidate.provenance == .aiEstimatePendingVerification
        )
    }
}

enum DateNavigator {
    static func nextDay(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }

    static func previousDay(before date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    static func isToday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(date)
    }
}

enum MealGrouping {
    static func sections(groups: [MealGroup], logs: [FoodLog], items: [FoodLogItem]) -> [MealSection] {
        let groupsByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let itemsByLogID = Dictionary(grouping: items, by: { $0.foodLogID })
        return MealType.allCases.map { mealType in
            let mealGroups = groups.filter { $0.mealType == mealType }
            let mealLogs = logs.filter { log in
                guard let groupID = log.mealGroupID, let group = groupsByID[groupID] else { return false }
                return group.mealType == mealType
            }
            return MealSection(mealType: mealType, groups: mealGroups, logs: mealLogs, itemsByLogID: itemsByLogID)
        }
    }
}
