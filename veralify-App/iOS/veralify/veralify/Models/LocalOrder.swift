import Foundation

struct LocalOrder: Codable, Identifiable, Hashable {
    let id: String
    let userID: String
    let airaloOrderID: Int
    let airaloOrderCode: String
    let packageID: String
    let packageTitle: String
    let countryCode: String
    let countryName: String
    let dataText: String
    let validityDays: Int
    let price: Double
    let iccid: String
    let lpa: String
    let matchingID: String
    let qrcode: String
    let qrcodeURL: String?
    let directAppleInstallURL: String?
    let createdAt: Date

    var formattedDate: String {
        Self.dateFormatter.string(from: createdAt)
    }
    var formattedPrice: String { String(format: "$%.2f", price) }
    var flagEmoji: String { countryCode.toFlagEmoji() }

    /// Best-effort expiry: purchase date + plan validity. Used for the
    /// compact history rows on the My eSIMs screen.
    var expiryDate: Date {
        Calendar.current.date(byAdding: .day, value: validityDays, to: createdAt) ?? createdAt
    }
    var isExpired: Bool { expiryDate < Date() }
    var formattedExpiry: String {
        let prefix = isExpired ? "Expired" : "Expires"
        return "\(prefix) \(Self.dateFormatter.string(from: expiryDate))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
