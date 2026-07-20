import Foundation

struct ChatAttachment: Identifiable, Hashable {
    enum Kind: Hashable {
        case flight(FlightOption)
        case esim(ESIMCatalogItem)
    }

    let id = UUID()
    let kind: Kind

    static func flight(_ option: FlightOption) -> ChatAttachment {
        ChatAttachment(kind: .flight(option))
    }

    static func esim(_ item: ESIMCatalogItem) -> ChatAttachment {
        ChatAttachment(kind: .esim(item))
    }
}
