import Foundation

struct FlightOption: Identifiable, Codable, Hashable {
    let id: String
    let airline: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureTime: String
    let arrivalTime: String
    let stops: Int
    let price: Double

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
}

struct ESIMCatalogItem: Identifiable, Codable, Hashable {
    let id: String
    let countryCode: String
    let countryName: String
    let packageName: String
    let dataAllowance: String
    let validityDays: Int
    let price: Double

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
}

struct CheckoutReceipt: Codable, Hashable {
    let transactionID: String
    let serviceType: String
    let amount: Double
    let currency: String
    let status: String
    let createdAtISO8601: String

    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }
}
