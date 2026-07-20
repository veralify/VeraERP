import Foundation
#if canImport(AgentSquad)
import AgentSquad
#endif

@MainActor
final class VeralifyAgentManager {
    static let shared = VeralifyAgentManager()

    let routerAgent = VeralifyAgent(
        agentID: .router,
        displayName: "Router Agent",
        mission: "Handles greetings, lifestyle chat, and routes travel intents to specialists.",
        modelName: "gpt-4o-mini",
        tools: [.searchFlights, .fetchESIMCatalog, .checkoutService]
    )

    let flightAgent = VeralifyAgent(
        agentID: .flightOTA,
        displayName: "Flight OTA Agent",
        mission: "Handles flight search and booking intents through the Veralify backend gateway.",
        modelName: "gpt-4o-mini",
        tools: [.searchFlights, .checkoutService]
    )

    let esimAgent = VeralifyAgent(
        agentID: .esim,
        displayName: "eSIM Agent",
        mission: "Handles data package discovery and eSIM provisioning intents.",
        modelName: "gpt-4o-mini",
        tools: [.fetchESIMCatalog, .checkoutService]
    )

    private(set) var registeredAgents: [VeralifyAgent] = []
    private let backendService: BackendService
    private let tools: VeralifyToolRegistry

    private var isBootstrapped = false

    init(
        backendService: BackendService = .shared,
        tools: VeralifyToolRegistry = VeralifyToolRegistry()
    ) {
        self.backendService = backendService
        self.tools = tools
        initializeAgentSquad()
    }

    // MARK: - Public API

    func streamResponse(
        for userInput: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<VeralifyAgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let selectedAgent = route(for: userInput)
                    switch selectedAgent {
                    case .router:
                        try await handleRouterMessage(userInput, history: history, continuation: continuation)
                    case .flightOTA:
                        try await handleFlightMessage(userInput, continuation: continuation)
                    case .esim:
                        try await handleESIMMessage(userInput, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Agent Squad Bootstrap

    private func initializeAgentSquad() {
        guard !isBootstrapped else { return }
        registeredAgents = [routerAgent, flightAgent, esimAgent]

        // Hook the Agent Squad runtime here once the SDK package is linked in the target.
        // The app already has concrete agent identities and tool contracts, so wiring is direct.
        isBootstrapped = true
    }

    // MARK: - Routing

    private func route(for userInput: String) -> VeralifyAgentID {
        let text = userInput.lowercased()

        let flightKeywords = ["flight", "book", "ticket", "airline", "departure", "arrival"]
        if flightKeywords.contains(where: text.contains) {
            return .flightOTA
        }

        let esimKeywords = ["esim", "data plan", "sim card", "roaming", "gigabytes", "gb"]
        if esimKeywords.contains(where: text.contains) {
            return .esim
        }

        return .router
    }

    // MARK: - Agent Handlers

    private func handleRouterMessage(
        _ userInput: String,
        history: [ChatMessage],
        continuation: AsyncThrowingStream<VeralifyAgentEvent, Error>.Continuation
    ) async throws {
        let gatewayHistory = history.compactMap(\.gatewayMessage)
        let stream = await backendService.streamChat(
            prompt: userInput,
            conversation: gatewayHistory,
            agentID: routerAgent.id
        )

        for try await token in stream {
            continuation.yield(.textDelta(token))
        }
    }

    private func handleFlightMessage(
        _ userInput: String,
        continuation: AsyncThrowingStream<VeralifyAgentEvent, Error>.Continuation
    ) async throws {
        let destination = extractDestination(from: userInput) ?? "LON"
        let date = extractDate(from: userInput) ?? Self.defaultTravelDate()

        await streamSentence(
            "Perfect. I am asking our flight desk for the best fares to \(destination) on \(date).",
            continuation: continuation
        )

        let results = try await tools.searchFlights(destination: destination, date: date)
        continuation.yield(.flightOptions(results))

        if userInput.lowercased().contains("checkout") || userInput.lowercased().contains("book now") {
            let quote = results.first?.price ?? 0
            let receipt = try await tools.checkoutService(serviceType: "flight", amount: quote)
            continuation.yield(.checkout(receipt))
            await streamSentence("Checkout authorization is prepared. Confirm to issue the ticket.", continuation: continuation)
        } else {
            await streamSentence("These options are ready. Say \"book now\" and I will prepare checkout.", continuation: continuation)
        }
    }

    private func handleESIMMessage(
        _ userInput: String,
        continuation: AsyncThrowingStream<VeralifyAgentEvent, Error>.Continuation
    ) async throws {
        let countryCode = extractCountryCode(from: userInput) ?? "US"

        await streamSentence(
            "Great choice. I am loading premium data plans for \(countryCode).",
            continuation: continuation
        )

        let catalog = try await tools.fetch_eSIM_Catalog(countryCode: countryCode)
        continuation.yield(.esimCatalog(catalog))

        if userInput.lowercased().contains("checkout") || userInput.lowercased().contains("buy now") {
            let quote = catalog.first?.price ?? 0
            let receipt = try await tools.checkoutService(serviceType: "esim", amount: quote)
            continuation.yield(.checkout(receipt))
            await streamSentence("Your eSIM checkout authorization is ready for confirmation.", continuation: continuation)
        } else {
            await streamSentence("Pick a plan and I can trigger secure checkout in one step.", continuation: continuation)
        }
    }

    // MARK: - Helpers

    private func streamSentence(
        _ sentence: String,
        continuation: AsyncThrowingStream<VeralifyAgentEvent, Error>.Continuation
    ) async {
        for token in sentence.split(separator: " ", omittingEmptySubsequences: true) {
            continuation.yield(.textDelta(String(token) + " "))
            try? await Task.sleep(for: .milliseconds(45))
        }
    }

    private func extractDestination(from text: String) -> String? {
        let words = text.split(separator: " ")
        guard let toIndex = words.firstIndex(where: { $0.lowercased() == "to" }) else {
            return nil
        }

        var destinationWords: [Substring] = []
        var index = words.index(after: toIndex)
        let stopWords = Set(["on", "for", "from", "in", "at", "with"])

        while index < words.endIndex {
            let lowerWord = words[index].lowercased()
            if stopWords.contains(lowerWord) {
                break
            }
            destinationWords.append(words[index])
            index = words.index(after: index)
        }

        let joined = destinationWords.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        return joined.isEmpty ? nil : joined.uppercased()
    }

    private func extractDate(from text: String) -> String? {
        let pattern = #"\d{4}-\d{2}-\d{2}"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range, in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func extractCountryCode(from text: String) -> String? {
        let candidates = text.split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters).uppercased() }

        return candidates.first(where: { $0.count == 2 && $0.allSatisfy(\.isLetter) })
    }

    private static func defaultTravelDate() -> String {
        let date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
