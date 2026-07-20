import Foundation

enum VeralifyToolName: String, CaseIterable, Hashable {
    case searchFlights
    case fetchESIMCatalog = "fetch_eSIM_Catalog"
    case checkoutService
}

enum VeralifyAgentID: String, CaseIterable, Hashable {
    case router = "router-agent"
    case flightOTA = "flight-ota-agent"
    case esim = "esim-agent"
}

struct VeralifyAgent: Identifiable, Hashable {
    let agentID: VeralifyAgentID
    let displayName: String
    let mission: String
    let modelName: String
    let tools: [VeralifyToolName]

    var id: String { agentID.rawValue }
}
