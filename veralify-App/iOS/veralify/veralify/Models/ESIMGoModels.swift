import Foundation

// MARK: - Catalogue

struct ESIMGoCatalogueBundle: Codable {
    let name: String
    let description: String
    let countries: [ESIMGOCountry]
    let dataAmount: Int?
    let duration: Int?
    let unlimited: Bool?
    let price: Double

    enum CodingKeys: String, CodingKey {
        case name, description, countries, duration, unlimited
        case dataAmount, price
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        countries = try c.decodeIfPresent([ESIMGOCountry].self, forKey: .countries) ?? []
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        unlimited = try c.decodeIfPresent(Bool.self, forKey: .unlimited)
        dataAmount = try c.decodeIfPresent(Int.self, forKey: .dataAmount)

        if let double = try? c.decode(Double.self, forKey: .price) {
            price = double
        } else if let int = try? c.decode(Int.self, forKey: .price) {
            price = Double(int)
        } else if let str = try? c.decode(String.self, forKey: .price), let p = Double(str) {
            price = p
        } else {
            throw DecodingError.dataCorruptedError(forKey: .price, in: c, debugDescription: "Invalid price value")
        }
    }
}

struct ESIMGOCountry: Codable {
    let name: String
    let region: String?
    let iso: String
}

// MARK: - Orders

struct ESIMGoCreateOrderRequest: Codable {
    let type: String
    let assign: Bool
    let profileID: String?
    let order: [OrderItem]

    enum CodingKeys: String, CodingKey {
        case type, assign, order
        case profileID
    }

    struct OrderItem: Codable {
        let type: String
        let quantity: Int
        let item: String
        let iccids: [String]?
        let allowReassign: Bool
    }
}

struct ESIMGoOrderResponse: Codable {
    let order: [ESIMGoOrderItem]
    let total: Double
    let currency: String
    let status: String?
    let statusMessage: String?
    let orderReference: String
    let createdDate: String
    let assigned: Bool

    enum CodingKeys: String, CodingKey {
        case order, total, currency, status, statusMessage, orderReference, createdDate, assigned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = try c.decode([ESIMGoOrderItem].self, forKey: .order)
        currency = try c.decode(String.self, forKey: .currency)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        statusMessage = try c.decodeIfPresent(String.self, forKey: .statusMessage)
        orderReference = try c.decode(String.self, forKey: .orderReference)
        createdDate = try c.decode(String.self, forKey: .createdDate)
        assigned = try c.decode(Bool.self, forKey: .assigned)
        total = try c.decodeFlexibleDouble(forKey: .total)
    }
}

struct ESIMGoOrderItem: Codable {
    let type: String
    let item: String
    let quantity: Int
    let subTotal: Double?
    let pricePerUnit: Double?
    let allowReassign: Bool?

    enum CodingKeys: String, CodingKey {
        case type, item, quantity, subTotal, pricePerUnit
        case allowReassign = "AllowReassign"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        item = try c.decode(String.self, forKey: .item)
        quantity = try c.decodeFlexibleInt(forKey: .quantity)
        subTotal = try c.decodeFlexibleOptionalDouble(forKey: .subTotal)
        pricePerUnit = try c.decodeFlexibleOptionalDouble(forKey: .pricePerUnit)
        allowReassign = try c.decodeIfPresent(Bool.self, forKey: .allowReassign)
    }
}

struct ESIMGoOrderResult: Codable {
    let orderReference: String
    let item: String
    let quantity: Int
    let total: Double
    let createdDate: String
    let esims: [ESIMGoInstalledESIM]
}

// MARK: - Install details

typealias ESIMGoInstallDetailsResponse = [ESIMGoInstalledESIM]

struct ESIMGoInstalledESIM: Codable {
    let iccid: String
    let matchingId: String
    let smdpAddress: String
    let appleInstallUrl: String?
}

// MARK: - eSIM Bundles / Usage

struct ESIMGoESIMBundlesResponse: Codable {
    let bundles: [ESIMGoAssignedBundle]
}

struct ESIMGoAssignedBundle: Codable {
    let name: String
    let description: String?
    let assignments: [ESIMGoBundleAssignment]
}

struct ESIMGoBundleAssignment: Codable {
    let id: String?
    let initialQuantity: Int?
    let remainingQuantity: Int?
    let assignmentDateTime: String
    let assignmentReference: String?
    let bundleState: String
    let endDateTime: String?
    let unlimited: Bool?
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key), let parsed = Double(value) { return parsed }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected Double-compatible value")
    }

    func decodeFlexibleOptionalDouble(forKey key: Key) throws -> Double? {
        guard contains(key) else { return nil }
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key), let parsed = Double(value) { return parsed }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key), let parsed = Int(value) { return parsed }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected Int-compatible value")
    }
}

// MARK: - App-facing usage model

struct SIMUsage: Codable {
    let remaining: Int?
    let total: Int?
    let status: String?
    let expiredAt: String?

    enum CodingKeys: String, CodingKey {
        case remaining, total, status
        case expiredAt = "expired_at"
    }

    var remainingGB: Double { Double(remaining ?? 0) / 1_073_741_824 }
    var totalGB: Double { Double(total ?? 0) / 1_073_741_824 }

    var usageFraction: Double {
        guard let t = total, t > 0, let r = remaining else { return 0 }
        return 1.0 - (Double(r) / Double(t))
    }

    var formattedRemaining: String {
        let mb = Double(remaining ?? 0) / 1_048_576
        return mb >= 1024 ? String(format: "%.2f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }

    var displayStatus: String { status?.capitalized ?? "Unknown" }
    var isActive: Bool { status?.uppercased() == "ACTIVE" }
}
