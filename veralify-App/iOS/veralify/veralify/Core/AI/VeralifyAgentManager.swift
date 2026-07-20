import Foundation
import AgentSquad

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
    private let tools: VeralifyToolRegistry
    private let orchestrator: Orchestrator
    private let userID = "guest-user"
    private let sessionID = "veralify-concierge"

    init(tools: VeralifyToolRegistry = VeralifyToolRegistry()) {
        self.tools = tools
        registeredAgents = [routerAgent, flightAgent, esimAgent]
        orchestrator = Self.buildOrchestrator(using: tools)
    }

    // MARK: - Public API

    func streamResponse(
        for userInput: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<VeralifyAgentEvent, Error> {
        _ = history

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var emittedTextDelta = false
                    let events = orchestrator.route(.text(userInput), userId: userID, sessionId: sessionID)

                    for try await event in events {
                        switch event {
                        case .textDelta(let token):
                            emittedTextDelta = true
                            continuation.yield(.textDelta(token))
                        case .widget(let payload):
                            for mappedEvent in Self.mapWidgetPayload(payload) {
                                continuation.yield(mappedEvent)
                            }
                        case .final(let message):
                            if !emittedTextDelta {
                                let fallbackText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !fallbackText.isEmpty {
                                    continuation.yield(.textDelta(fallbackText))
                                }
                            }
                        case .error(let message):
                            continuation.yield(.textDelta(message))
                        case .thinking, .toolCall:
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Setup

    private static func buildOrchestrator(using tools: VeralifyToolRegistry) -> Orchestrator {
        let llm = ChatCompletionsClient(
            baseURL: URL(string: AppConfig.backendGatewayBaseURL) ?? URL(string: "https://api.veralify.com/v1")!,
            model: "gpt-4o-mini"
        )

        let routerAgent = Agent(
            name: "Router Agent",
            description: "Primary concierge for greetings and intent routing across travel experiences.",
            model: llm,
            tools: buildRouterTools(using: tools)
        )
        let flightAgent = Agent(
            name: "Flight OTA Agent",
            description: """
            Flight specialist for trip planning and booking flow.
            Always call searchFlights before proposing flight options.
            Use checkoutService only after the user confirms booking intent.
            """,
            model: llm,
            tools: buildFlightTools(using: tools)
        )
        let esimAgent = Agent(
            name: "eSIM Agent",
            description: """
            eSIM specialist for package discovery and provisioning support.
            Always call fetch_eSIM_Catalog before recommending plans.
            Use checkoutService only when user explicitly asks to buy or checkout.
            """,
            model: llm,
            tools: buildESIMTools(using: tools)
        )

        return Orchestrator(
            agents: [routerAgent, flightAgent, esimAgent],
            classifier: LLMClassifier(model: llm),
            store: FileChatStorage()
        )
    }

    private static func buildRouterTools(using tools: VeralifyToolRegistry) -> ToolProvider {
        ToolKit(
            searchFlightsTool(using: tools),
            fetchESIMCatalogTool(using: tools),
            checkoutTool(using: tools)
        )
    }

    private static func buildFlightTools(using tools: VeralifyToolRegistry) -> ToolProvider {
        ToolKit(
            searchFlightsTool(using: tools),
            checkoutTool(using: tools)
        )
    }

    private static func buildESIMTools(using tools: VeralifyToolRegistry) -> ToolProvider {
        ToolKit(
            fetchESIMCatalogTool(using: tools),
            checkoutTool(using: tools)
        )
    }

    // MARK: - Tool Definitions

    private static func searchFlightsTool(using tools: VeralifyToolRegistry) -> Tool {
        Tool.local(
            name: VeralifyToolName.searchFlights.rawValue,
            description: "Search flights by destination and date (YYYY-MM-DD).",
            inputSchema: [
                .string("destination", "IATA code or city name.", required: true),
                .string("date", "Travel date in YYYY-MM-DD.", required: true),
            ].objectSchema(),
            ui: "ui://veralify/flights"
        ) { arguments in
            guard
                let destination = arguments["destination"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !destination.isEmpty,
                let date = arguments["date"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !date.isEmpty
            else {
                return .failure("destination and date are required.")
            }

            let flights = try await tools.searchFlights(destination: destination, date: date)
            let payload = flightWidgetPayload(from: flights)
            return ToolResult(
                content: [.text("Found \(flights.count) flight options for \(destination.uppercased()) on \(date).")],
                structuredContent: payload,
                ui: UIPayload(
                    resourceURI: "ui://veralify/flights",
                    mimeType: "application/vnd.veralify.flight-options+json",
                    structuredContent: payload
                )
            )
        }
    }

    private static func fetchESIMCatalogTool(using tools: VeralifyToolRegistry) -> Tool {
        Tool.local(
            name: VeralifyToolName.fetchESIMCatalog.rawValue,
            description: "Fetch eSIM plans for a specific 2-letter country code (ISO alpha-2).",
            inputSchema: [
                .string("countryCode", "Country code like US, AE, JP.", required: true),
            ].objectSchema(),
            ui: "ui://veralify/esim-catalog"
        ) { arguments in
            guard
                let countryCode = arguments["countryCode"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !countryCode.isEmpty
            else {
                return .failure("countryCode is required.")
            }

            let catalog = try await tools.fetch_eSIM_Catalog(countryCode: countryCode)
            let payload = esimWidgetPayload(from: catalog)
            return ToolResult(
                content: [.text("Found \(catalog.count) eSIM plans for \(countryCode.uppercased()).")],
                structuredContent: payload,
                ui: UIPayload(
                    resourceURI: "ui://veralify/esim-catalog",
                    mimeType: "application/vnd.veralify.esim-catalog+json",
                    structuredContent: payload
                )
            )
        }
    }

    private static func checkoutTool(using tools: VeralifyToolRegistry) -> Tool {
        Tool.local(
            name: VeralifyToolName.checkoutService.rawValue,
            description: "Authorize checkout for a service type and amount.",
            inputSchema: [
                .string("serviceType", "Service name, e.g. flight or esim.", required: true),
                .number("amount", "Total amount in USD.", required: true),
            ].objectSchema(),
            ui: "ui://veralify/checkout"
        ) { arguments in
            guard
                let serviceType = arguments["serviceType"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !serviceType.isEmpty,
                let amount = arguments["amount"]?.doubleValue
            else {
                return .failure("serviceType and amount are required.")
            }

            let receipt = try await tools.checkoutService(serviceType: serviceType, amount: amount)
            let payload = checkoutWidgetPayload(from: receipt)
            return ToolResult(
                content: [.text("Checkout authorized for \(receipt.formattedAmount) \(receipt.currency).")],
                structuredContent: payload,
                ui: UIPayload(
                    resourceURI: "ui://veralify/checkout",
                    mimeType: "application/vnd.veralify.checkout+json",
                    structuredContent: payload
                )
            )
        }
    }

    // MARK: - Widget Encoding

    private nonisolated static func flightWidgetPayload(from flights: [FlightOption]) -> JSONValue {
        .object([
            "kind": .string("flightOptions"),
            "items": .array(
                flights.map { flight in
                    .object([
                        "id": .string(flight.id),
                        "airline": .string(flight.airline),
                        "flightNumber": .string(flight.flightNumber),
                        "origin": .string(flight.origin),
                        "destination": .string(flight.destination),
                        "departureTime": .string(flight.departureTime),
                        "arrivalTime": .string(flight.arrivalTime),
                        "stops": .int(flight.stops),
                        "price": .double(flight.price),
                    ])
                }
            ),
        ])
    }

    private nonisolated static func esimWidgetPayload(from catalog: [ESIMCatalogItem]) -> JSONValue {
        .object([
            "kind": .string("esimCatalog"),
            "items": .array(
                catalog.map { item in
                    .object([
                        "id": .string(item.id),
                        "countryCode": .string(item.countryCode),
                        "countryName": .string(item.countryName),
                        "packageName": .string(item.packageName),
                        "dataAllowance": .string(item.dataAllowance),
                        "validityDays": .int(item.validityDays),
                        "price": .double(item.price),
                    ])
                }
            ),
        ])
    }

    private nonisolated static func checkoutWidgetPayload(from receipt: CheckoutReceipt) -> JSONValue {
        .object([
            "kind": .string("checkout"),
            "receipt": .object([
                "transactionID": .string(receipt.transactionID),
                "serviceType": .string(receipt.serviceType),
                "amount": .double(receipt.amount),
                "currency": .string(receipt.currency),
                "status": .string(receipt.status),
                "createdAtISO8601": .string(receipt.createdAtISO8601),
            ]),
        ])
    }

    // MARK: - Widget Decoding

    private nonisolated static func mapWidgetPayload(_ payload: UIPayload) -> [VeralifyAgentEvent] {
        switch payload.resourceURI {
        case "ui://veralify/flights":
            let flights = parseFlights(payload.structuredContent)
            return flights.isEmpty ? [] : [.flightOptions(flights)]
        case "ui://veralify/esim-catalog":
            let catalog = parseESIMCatalog(payload.structuredContent)
            return catalog.isEmpty ? [] : [.esimCatalog(catalog)]
        case "ui://veralify/checkout":
            guard let receipt = parseCheckout(payload.structuredContent) else { return [] }
            return [.checkout(receipt)]
        default:
            return []
        }
    }

    private nonisolated static func parseFlights(_ json: JSONValue) -> [FlightOption] {
        guard case .object(let root) = json, case .array(let items)? = root["items"] else { return [] }

        return items.compactMap { item in
            guard
                case .object(let object) = item,
                case .string(let id)? = object["id"],
                case .string(let airline)? = object["airline"],
                case .string(let flightNumber)? = object["flightNumber"],
                case .string(let origin)? = object["origin"],
                case .string(let destination)? = object["destination"],
                case .string(let departureTime)? = object["departureTime"],
                case .string(let arrivalTime)? = object["arrivalTime"],
                let stops = object["stops"]?.intValue,
                let price = object["price"]?.doubleValue
            else {
                return nil
            }

            return FlightOption(
                id: id,
                airline: airline,
                flightNumber: flightNumber,
                origin: origin,
                destination: destination,
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                stops: stops,
                price: price
            )
        }
    }

    private nonisolated static func parseESIMCatalog(_ json: JSONValue) -> [ESIMCatalogItem] {
        guard case .object(let root) = json, case .array(let items)? = root["items"] else { return [] }

        return items.compactMap { item in
            guard
                case .object(let object) = item,
                case .string(let id)? = object["id"],
                case .string(let countryCode)? = object["countryCode"],
                case .string(let countryName)? = object["countryName"],
                case .string(let packageName)? = object["packageName"],
                case .string(let dataAllowance)? = object["dataAllowance"],
                let validityDays = object["validityDays"]?.intValue,
                let price = object["price"]?.doubleValue
            else {
                return nil
            }

            return ESIMCatalogItem(
                id: id,
                countryCode: countryCode,
                countryName: countryName,
                packageName: packageName,
                dataAllowance: dataAllowance,
                validityDays: validityDays,
                price: price
            )
        }
    }

    private nonisolated static func parseCheckout(_ json: JSONValue) -> CheckoutReceipt? {
        guard
            case .object(let root) = json,
            case .object(let receipt)? = root["receipt"],
            case .string(let transactionID)? = receipt["transactionID"],
            case .string(let serviceType)? = receipt["serviceType"],
            let amount = receipt["amount"]?.doubleValue,
            case .string(let currency)? = receipt["currency"],
            case .string(let status)? = receipt["status"],
            case .string(let createdAtISO8601)? = receipt["createdAtISO8601"]
        else {
            return nil
        }

        return CheckoutReceipt(
            transactionID: transactionID,
            serviceType: serviceType,
            amount: amount,
            currency: currency,
            status: status,
            createdAtISO8601: createdAtISO8601
        )
    }
}
