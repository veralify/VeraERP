import Foundation

struct OnboardingProfile: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let username: String
    let displayName: String?
    let heightCm: Double?
    let activityLevel: ProfileActivityLevel?
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, username
        case displayName = "display_name"
        case heightCm = "height_cm"
        case activityLevel = "activity_level"
        case onboardingCompleted = "onboarding_completed"
    }
}

private struct ProfilePayload: Encodable {
    let id: String
    let username: String
    let email: String?
    let display_name: String?
    let height_cm: Double?
    let activity_level: ProfileActivityLevel?
    let date_of_birth: String?
    let timezone: String?
    let onboarding_completed: Bool
}

private struct ProfileCompletionPayload: Encodable {
    let onboarding_completed: Bool
}

private struct ProfilePreferencePayload: Encodable {
    let user_id: String
    let units: UnitsSystem
    let dietary_preferences: EmptyJSONObject
    let fitness_preferences: FitnessPreferences
    let notification_preferences: EmptyJSONObject
    let ai_preferences: EmptyJSONObject
}

private struct EmptyJSONObject: Encodable {}

private struct FitnessPreferences: Encodable {
    let primary_goal_type: String
    let current_weight_kg: Double
    let target_weight_kg: Double?
    let target_date: String?
    let sex: String
    let age: Int
}

private struct GoalPayload: Codable {
    let user_id: String
    let type: String
    let title: String
    let description: String?
    let target_value: Double?
    let starting_value: Double?
    let unit: String?
    let start_date: String?
    let target_date: String?
    let status: String?
}

private struct GoalRow: Codable, Identifiable {
    let id: String
    let user_id: String
    let type: String
    let title: String
}

private struct GoalTargetPayload: Codable {
    let goal_id: String
    let metric: String
    let target_value: Double
    let unit: String?
    let period: String?
}

private struct GoalTargetRow: Codable, Identifiable {
    let id: String
    let goal_id: String
    let metric: String
}

@MainActor
final class OnboardingRepository {
    private let supabase = SupabaseClient.shared
    private let encoder = JSONEncoder()
    private let draftKey = "veralify.onboarding.draft.v1"

    func loadProfile() async throws -> OnboardingProfile? {
        let user = try await supabase.getUser()
        let rows: [OnboardingProfile] = try await supabase.select(from: "profiles", filters: ["id": user.id])
        return rows.first
    }

    func saveDraftLocally(_ draft: OnboardingDraft) {
        guard let data = try? encoder.encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
    }

    func loadDraftLocally() -> OnboardingDraft {
        guard
            let data = UserDefaults.standard.data(forKey: draftKey),
            let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data)
        else { return OnboardingDraft() }
        return draft
    }

    func saveGoalChoice(_ draft: OnboardingDraft) async throws {
        try await savePreferences(draft)
    }

    func saveProfileSetup(_ draft: OnboardingDraft) async throws {
        let user = try await supabase.getUser()
        let payload = ProfilePayload(
            id: user.id,
            username: username(for: user),
            email: user.email,
            display_name: user.email?.components(separatedBy: "@").first,
            height_cm: draft.heightCm,
            activity_level: draft.activityLevel,
            date_of_birth: birthDateString(age: draft.age),
            timezone: TimeZone.current.identifier,
            onboarding_completed: false
        )
        let _: OnboardingProfile = try await supabase.upsert(
            into: "profiles",
            data: payload,
            returning: OnboardingProfile.self,
            onConflict: "id"
        )
        try await savePreferences(draft)
    }

    func saveTarget(_ draft: OnboardingDraft) async throws {
        try await savePreferences(draft)
    }

    func savePlan(_ draft: OnboardingDraft, plan: NutritionPlan) async throws {
        let user = try await supabase.getUser()
        let goal = try await upsertGoal(userID: user.id, draft: draft)
        try await upsertTarget(goalID: goal.id, metric: "calories", value: Double(plan.dailyCalories), unit: "kcal")
        try await upsertTarget(goalID: goal.id, metric: "protein_g", value: Double(plan.proteinGrams), unit: "g")
        try await upsertTarget(goalID: goal.id, metric: "fat_g", value: Double(plan.fatGrams), unit: "g")
        try await upsertTarget(goalID: goal.id, metric: "carbs_g", value: Double(plan.carbGrams), unit: "g")
    }

    func completeOnboarding() async throws {
        let user = try await supabase.getUser()
        let payload = ProfileCompletionPayload(onboarding_completed: true)
        let _: OnboardingProfile = try await supabase.update(
            table: "profiles",
            data: payload,
            returning: OnboardingProfile.self,
            filters: ["id": user.id]
        )
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    private func savePreferences(_ draft: OnboardingDraft) async throws {
        let user = try await supabase.getUser()
        let payload = ProfilePreferencePayload(
            user_id: user.id,
            units: draft.units,
            dietary_preferences: EmptyJSONObject(),
            fitness_preferences: FitnessPreferences(
                primary_goal_type: draft.selectedGoal.rawValue,
                current_weight_kg: draft.weightKg,
                target_weight_kg: draft.targetWeightKg,
                target_date: Self.dateFormatter.string(from: draft.targetDate),
                sex: draft.sex.rawValue,
                age: draft.age
            ),
            notification_preferences: EmptyJSONObject(),
            ai_preferences: EmptyJSONObject()
        )
        let _: PreferenceRow = try await supabase.upsert(
            into: "profile_preferences",
            data: payload,
            returning: PreferenceRow.self,
            onConflict: "user_id"
        )
    }

    private func upsertGoal(userID: String, draft: OnboardingDraft) async throws -> GoalRow {
        let existing: [GoalRow] = try await supabase.select(
            from: "goals",
            columns: "id,user_id,type,title",
            filters: ["user_id": userID, "type": draft.selectedGoal.rawValue, "status": "active"]
        )
        let payload = GoalPayload(
            user_id: userID,
            type: draft.selectedGoal.rawValue,
            title: draft.selectedGoal.title,
            description: "Deterministic onboarding nutrition plan",
            target_value: draft.targetWeightKg,
            starting_value: draft.weightKg,
            unit: "kg",
            start_date: Self.dateFormatter.string(from: Date()),
            target_date: Self.dateFormatter.string(from: draft.targetDate),
            status: "active"
        )
        if let goal = existing.first {
            return try await supabase.update(table: "goals", data: payload, returning: GoalRow.self, filters: ["id": goal.id])
        }
        return try await supabase.insert(into: "goals", data: payload, returning: GoalRow.self)
    }

    private func upsertTarget(goalID: String, metric: String, value: Double, unit: String) async throws {
        let existing: [GoalTargetRow] = try await supabase.select(
            from: "goal_targets",
            columns: "id,goal_id,metric",
            filters: ["goal_id": goalID, "metric": metric]
        )
        let payload = GoalTargetPayload(goal_id: goalID, metric: metric, target_value: value, unit: unit, period: "daily")
        if let target = existing.first {
            let _: GoalTargetRow = try await supabase.update(table: "goal_targets", data: payload, returning: GoalTargetRow.self, filters: ["id": target.id])
        } else {
            let _: GoalTargetRow = try await supabase.insert(into: "goal_targets", data: payload, returning: GoalTargetRow.self)
        }
    }

    private func username(for user: AuthUser) -> String {
        let raw = user.email?.components(separatedBy: "@").first ?? "veralify"
        let base = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(18)
        let suffix = user.id.replacingOccurrences(of: "-", with: "").prefix(8)
        return "\(base.isEmpty ? "user" : String(base))_\(suffix)"
    }

    private func birthDateString(age: Int) -> String {
        let year = Calendar.current.component(.year, from: Date()) - age
        return "\(year)-01-01"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct PreferenceRow: Decodable {
    let user_id: String
}
