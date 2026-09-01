import Foundation

struct CommunityGroup: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String?
    let goalType: String?
    let type: String
    let visibility: String
    let memberLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, visibility
        case goalType = "goal_type"
        case memberLimit = "member_limit"
    }
}

enum CommunityLoadState: Equatable {
    case idle
    case loading
    case loaded([CommunityGroup])
    case notYetAvailable
}

@MainActor
final class CommunityRepository {
    private let supabase = SupabaseClient.shared

    func recommendedGroups(goalType: OnboardingGoalType) async throws -> [CommunityGroup] {
        _ = goalType
        let rows: [CommunityGroup] = try await supabase.select(
            from: "groups",
            columns: "id,name,description,goal_type,type,visibility,member_limit",
            filters: ["is_active": "true", "visibility": "public"]
        )
        return Array(rows.prefix(6))
    }
}
