import Foundation

struct GatewayChatMessage: Codable, Hashable {
    let role: String
    let content: String
}

struct GatewayChatRequest: Encodable {
    let agentID: String
    let model: String
    let messages: [GatewayChatMessage]
    let prompt: String
}

struct GatewayStreamChunk: Decodable {
    let delta: String?
    let content: String?
}
