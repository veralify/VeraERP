import Foundation

enum EntitlementKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case aiFoodLogging = "ai_food_logging"
    case advancedAI = "advanced_ai"
    case dailySummary = "daily_summary"
    case advancedNutrition = "advanced_nutrition"
    case unlimitedGroups = "unlimited_groups"
    case advancedProgress = "advanced_progress"
    case progressPhotos = "progress_photos"
    case advancedTrends = "advanced_trends"
    case liveRooms = "live_rooms"
    case premiumLiveRooms = "premium_live_rooms"
    case coachDiscovery = "coach_discovery"
    case coachClientManagement = "coach_client_management"
    case coachClientData = "coach_client_data"
    case coachVideoSessions = "coach_video_sessions"
    case coachGroupSessions = "coach_group_sessions"
    case coachScheduling = "coach_scheduling"
    case coachDashboard = "coach_dashboard"

    var id: String { rawValue }
}
