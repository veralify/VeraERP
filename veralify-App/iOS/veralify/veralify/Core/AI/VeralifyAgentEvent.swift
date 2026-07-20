import Foundation

enum VeralifyAgentEvent: Hashable {
    case textDelta(String)
    case flightOptions([FlightOption])
    case esimCatalog([ESIMCatalogItem])
    case checkout(CheckoutReceipt)
}
