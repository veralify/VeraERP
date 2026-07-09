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

    init(
        packageID: String,
        slug: String?,
        type: String?,
        price: Double,
        netPrice: Double?,
        amount: Int?,
        day: Int,
        isUnlimited: Bool,
        title: String,
        data: String,
        shortInfo: String?,
        planType: String?,
        activationPolicy: String?,
        packageOperator: ESIMOperator,
        countries: [String]
    ) {
        self.packageID = packageID
        self.slug = slug
        self.type = type
        self.price = price
        self.netPrice = netPrice
        self.amount = amount
        self.day = day
        self.isUnlimited = isUnlimited
        self.title = title
        self.data = data
        self.shortInfo = shortInfo
        self.planType = planType
        self.activationPolicy = activationPolicy
        self.packageOperator = packageOperator
        self.countries = countries
    }

    init(bundle: ESIMGoCatalogueBundle) {
        packageID = bundle.name
        slug = bundle.name.lowercased()
        type = "bundle"
        price = bundle.price
        netPrice = nil
        amount = bundle.dataAmount
        day = bundle.duration ?? 0
        isUnlimited = bundle.unlimited ?? false
        title = bundle.description
        data = Self.formatDataText(from: bundle.dataAmount, unlimited: bundle.unlimited ?? false)
        shortInfo = bundle.description
        planType = "data"
        activationPolicy = "first-usage"
        packageOperator = ESIMOperator(title: "eSIM Go", isRoaming: true, info: nil)
        countries = bundle.countries.map(\.iso)
    }

    private static func formatDataText(from dataAmount: Int?, unlimited: Bool) -> String {
        if unlimited { return "Unlimited" }
        guard let dataAmount, dataAmount > 0 else { return "Data plan" }

        if dataAmount >= 1_000_000_000 {
            return String(format: "%.0f GB", Double(dataAmount) / 1_000_000_000)
        }
        if dataAmount >= 1_000_000 {
            return String(format: "%.0f MB", Double(dataAmount) / 1_000_000)
        }
        return "\(dataAmount) MB"
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
