import Foundation

enum VeralifyAgentID: String, CaseIterable, Hashable {
    case coach = "coach-agent"
}

struct VeralifyAgent: Identifiable, Hashable {
    let agentID: VeralifyAgentID
    let displayName: String
    let mission: String
    let modelName: String

    var id: String { agentID.rawValue }
}
