import Foundation

enum OnboardingStep: Int, CaseIterable, Codable, Hashable {
    case welcome
    case goalSelection
    case profileSetup
    case targetSetup
    case planReveal
    case paywall
    case communitySetup
}

enum OnboardingStateMachine {
    static func next(after step: OnboardingStep) -> OnboardingStep? {
        OnboardingStep(rawValue: step.rawValue + 1)
    }

    static func previous(before step: OnboardingStep) -> OnboardingStep? {
        OnboardingStep(rawValue: step.rawValue - 1)
    }
}

enum OnboardingGoalType: String, CaseIterable, Codable, Identifiable {
    case loseWeight = "lose_weight"
    case gainMuscle = "gain_muscle"
    case maintain
    case recomp
    case improveFitness = "improve_fitness"
    case improveNutrition = "improve_nutrition"
    case buildConsistency = "build_consistency"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: return "Lose fat"
        case .gainMuscle: return "Build muscle"
        case .maintain: return "Maintain"
        case .recomp: return "Recomposition"
        case .improveFitness: return "Improve fitness"
        case .improveNutrition: return "Improve nutrition"
        case .buildConsistency: return "Build consistency"
        }
    }

    var subtitle: String {
        switch self {
        case .loseWeight: return "Cut with high-protein targets."
        case .gainMuscle: return "Lean surplus for strength."
        case .maintain: return "Hold steady and build habits."
        case .recomp: return "Lose fat while preserving muscle."
        case .improveFitness: return "Performance-first maintenance."
        case .improveNutrition: return "Macro clarity and consistency."
        case .buildConsistency: return "Simple daily targets."
        }
    }
}

enum BiologicalSex: String, CaseIterable, Codable, Identifiable {
    case male
    case female
    case unspecified

    var id: String { rawValue }
    var title: String { self == .unspecified ? "Prefer not to say" : rawValue.capitalized }
}

enum ProfileActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive = "very_active"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum UnitsSystem: String, CaseIterable, Codable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct OnboardingDraft: Codable, Equatable {
    var selectedGoal: OnboardingGoalType = .loseWeight
    var units: UnitsSystem = .metric
    var heightCm: Double = 170
    var weightKg: Double = 75
    var age: Int = 30
    var sex: BiologicalSex = .unspecified
    var activityLevel: ProfileActivityLevel = .moderate
    var targetWeightKg: Double = 70
    var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var plan: NutritionPlan?
}
