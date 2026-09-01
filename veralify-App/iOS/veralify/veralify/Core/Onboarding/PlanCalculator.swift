import Foundation

struct NutritionPlan: Codable, Equatable {
    let bmr: Int
    let tdee: Int
    let dailyCalories: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbGrams: Int
}

enum PlanCalculator {
    // Mifflin-St Jeor: BMR = 10*kg + 6.25*cm - 5*age + sexConstant.
    // Sex constants: male +5, female -161, unspecified midpoint -78.
    // Activity factors are ProfileActivityLevel.factor. Goal calorie adjustments:
    // cut -500 (not below 110% BMR), recomp -150, bulk +250, maintain 0.
    // Protein/fat: cut/recomp 2.0g/kg protein, bulk 1.8, maintain 1.6; fat 0.8g/kg.
    static func compute(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        activityLevel: ProfileActivityLevel,
        goal: OnboardingGoalType
    ) -> NutritionPlan {
        let sexConstant: Double = switch sex {
        case .male: 5
        case .female: -161
        case .unspecified: -78
        }
        let bmrRaw = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sexConstant
        let tdeeRaw = bmrRaw * activityLevel.factor
        let caloriesRaw: Double = switch goal {
        case .loseWeight: max(tdeeRaw - 500, bmrRaw * 1.1)
        case .recomp: max(tdeeRaw - 150, bmrRaw)
        case .gainMuscle: tdeeRaw + 250
        case .maintain, .improveFitness, .improveNutrition, .buildConsistency: tdeeRaw
        }
        let proteinPerKg: Double = switch goal {
        case .loseWeight, .recomp: 2.0
        case .gainMuscle: 1.8
        case .maintain, .improveFitness, .improveNutrition, .buildConsistency: 1.6
        }
        let protein = weightKg * proteinPerKg
        let fat = weightKg * 0.8
        let carbCalories = max(0, caloriesRaw - (protein * 4) - (fat * 9))
        return NutritionPlan(
            bmr: Int(bmrRaw.rounded()),
            tdee: Int(tdeeRaw.rounded()),
            dailyCalories: Int(caloriesRaw.rounded()),
            proteinGrams: Int(protein.rounded()),
            fatGrams: Int(fat.rounded()),
            carbGrams: Int((carbCalories / 4).rounded())
        )
    }
}

enum UnitConversion {
    static func poundsToKilograms(_ pounds: Double) -> Double { pounds / 2.2046226218 }
    static func kilogramsToPounds(_ kilograms: Double) -> Double { kilograms * 2.2046226218 }
    static func inchesToCentimeters(_ inches: Double) -> Double { inches * 2.54 }
    static func centimetersToInches(_ centimeters: Double) -> Double { centimeters / 2.54 }
}
