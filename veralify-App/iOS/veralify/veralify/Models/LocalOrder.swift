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
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: createdAt)
    }
    var formattedPrice: String { String(format: "$%.2f", price) }
    var flagEmoji: String { countryCode.toFlagEmoji() }
}
