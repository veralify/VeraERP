import Foundation

enum PlanCategory: String, CaseIterable, Identifiable {
    case local = "Countries"
    case regional = "Regional"
    case global = "Global"
    var id: String { rawValue }
}

enum PackageType: String {
    case local = "local"
    case global = "global"
}

struct ESIMPackage: Codable, Identifiable {
    var id: String { packageID }
    let packageID: String
    let slug: String?
    let type: String?
    let price: Double
    let netPrice: Double?
    let amount: Int?
    let day: Int
    let isUnlimited: Bool
    let title: String
    let data: String
    let shortInfo: String?
    let planType: String?
    let activationPolicy: String?
    let packageOperator: ESIMOperator
    let countries: [String]

    enum CodingKeys: String, CodingKey {
        case slug, type, price, amount, day, title, data, countries
        case packageID = "package_id"
        case netPrice = "net_price"
        case isUnlimited = "is_unlimited"
        case shortInfo = "short_info"
        case planType = "plan_type"
        case activationPolicy = "activation_policy"
        case packageOperator = "operator"
    }

    var formattedPrice: String { String(format: "$%.2f", price) }
    var validityText: String { "\(day) \(day == 1 ? "Day" : "Days")" }
    var operatorName: String { packageOperator.title }

    var planCategory: PlanCategory {
        if countries.count == 1 { return .local }
        if countries.count < 50 { return .regional }
        return .global
    }
}

struct ESIMOperator: Codable {
    let title: String
    let isRoaming: Bool
    let info: [String]?
    enum CodingKeys: String, CodingKey {
        case title, info
        case isRoaming = "is_roaming"
    }
}
