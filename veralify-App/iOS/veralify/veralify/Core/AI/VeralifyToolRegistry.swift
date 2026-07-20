import Foundation

actor VeralifyToolRegistry {
    private let isoFormatter = ISO8601DateFormatter()

    // MARK: - Agent Tools (Mock Implementations)

    /// Simulates a Duffel-backed flight search request.
    func searchFlights(destination: String, date: String) async throws -> [FlightOption] {
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDestination.isEmpty else {
            throw APIError.httpError(statusCode: 400, message: "Destination is required.")
        }

        try await Task.sleep(for: .milliseconds(350))

        return [
            FlightOption(
                id: "\(normalizedDestination)-\(date)-EK203",
                airline: "Emirates",
                flightNumber: "EK203",
                origin: "DXB",
                destination: normalizedDestination.uppercased(),
                departureTime: "\(date) 08:20",
                arrivalTime: "\(date) 13:05",
                stops: 0,
                price: 649
            ),
            FlightOption(
                id: "\(normalizedDestination)-\(date)-QR731",
                airline: "Qatar Airways",
                flightNumber: "QR731",
                origin: "DOH",
                destination: normalizedDestination.uppercased(),
                departureTime: "\(date) 10:15",
                arrivalTime: "\(date) 15:40",
                stops: 1,
                price: 588
            ),
            FlightOption(
                id: "\(normalizedDestination)-\(date)-TK801",
                airline: "Turkish Airlines",
                flightNumber: "TK801",
                origin: "IST",
                destination: normalizedDestination.uppercased(),
                departureTime: "\(date) 14:45",
                arrivalTime: "\(date) 21:15",
                stops: 1,
                price: 532
            )
        ]
    }

    /// Simulates retrieval of eSIM plans for a country.
    func fetch_eSIM_Catalog(countryCode: String) async throws -> [ESIMCatalogItem] {
        let normalizedCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedCode.count == 2 else {
            throw APIError.httpError(statusCode: 400, message: "Use a 2-letter country code.")
        }

        try await Task.sleep(for: .milliseconds(300))
        let countryName = countryName(for: normalizedCode)

        return [
            ESIMCatalogItem(
                id: "\(normalizedCode)-1GB-7D",
                countryCode: normalizedCode,
                countryName: countryName,
                packageName: "\(countryName) Starter",
                dataAllowance: "1 GB",
                validityDays: 7,
                price: 5.99
            ),
            ESIMCatalogItem(
                id: "\(normalizedCode)-5GB-15D",
                countryCode: normalizedCode,
                countryName: countryName,
                packageName: "\(countryName) Explorer",
                dataAllowance: "5 GB",
                validityDays: 15,
                price: 16.99
            ),
            ESIMCatalogItem(
                id: "\(normalizedCode)-10GB-30D",
                countryCode: normalizedCode,
                countryName: countryName,
                packageName: "\(countryName) Premium",
                dataAllowance: "10 GB",
                validityDays: 30,
                price: 27.50
            )
        ]
    }

    /// Simulates a checkout call that will later bridge to Stripe.
    func checkoutService(serviceType: String, amount: Double) async throws -> CheckoutReceipt {
        guard amount > 0 else {
            throw APIError.httpError(statusCode: 400, message: "Checkout amount must be greater than zero.")
        }

        try await Task.sleep(for: .milliseconds(250))

        return CheckoutReceipt(
            transactionID: UUID().uuidString,
            serviceType: serviceType,
            amount: amount,
            currency: "USD",
            status: "authorized",
            createdAtISO8601: isoFormatter.string(from: Date())
        )
    }

    private func countryName(for code: String) -> String {
        switch code {
        case "AE":
            return "United Arab Emirates"
        case "US":
            return "United States"
        case "GB":
            return "United Kingdom"
        case "FR":
            return "France"
        case "JP":
            return "Japan"
        case "SA":
            return "Saudi Arabia"
        case "TR":
            return "Türkiye"
        default:
            return "Destination \(code)"
        }
    }
}
