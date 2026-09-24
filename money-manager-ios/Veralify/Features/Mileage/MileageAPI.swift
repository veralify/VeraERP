import Foundation
import VeralifyCore

/// One logged trip, as PostgREST returns it.
///
/// Money and distances are selected as text (`distance::text`) and parsed
/// here, because a JSON number goes through `Double` on the way into
/// `Decimal` and 0.45 comes back as 0.45000000000000001.
struct MileageTrip: Decodable, Identifiable, Sendable, Equatable {
    let id: UUID
    let tripDay: String
    let origin: String
    let destination: String
    let distance: Decimal
    let unit: DistanceUnit
    let ratePerUnit: Decimal
    let currency: String
    let purpose: String
    let isBusiness: Bool
    /// The linked expense's amount; nil if that expense was removed.
    let amount: Decimal?

    var claimed: Decimal { amount ?? Money.rounded(distance * ratePerUnit) }

    var date: Date { MileageAPI.date(fromDay: tripDay) ?? .distantPast }

    private enum CodingKeys: String, CodingKey {
        case id, origin, destination, distance, unit, currency, purpose, scope, transaction
        case tripDay = "trip_date"
        case ratePerUnit = "rate_per_unit"
    }

    private struct Transaction: Decodable {
        let amount: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripDay = try container.decode(String.self, forKey: .tripDay)
        origin = try container.decodeIfPresent(String.self, forKey: .origin) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        distance = Decimal(string: try container.decode(String.self, forKey: .distance), locale: MileageAPI.posix) ?? 0
        unit = try container.decode(DistanceUnit.self, forKey: .unit)
        ratePerUnit = Decimal(string: try container.decode(String.self, forKey: .ratePerUnit), locale: MileageAPI.posix) ?? 0
        currency = try container.decode(String.self, forKey: .currency)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        isBusiness = try container.decode(String.self, forKey: .scope) == "business"
        amount = try container.decodeIfPresent(Transaction.self, forKey: .transaction)?
            .amount
            .flatMap { Decimal(string: $0, locale: MileageAPI.posix) }
    }
}

/// What the trip sheet sends. Money travels as decimal strings (contract §2).
struct NewMileageTrip: Sendable {
    let id: UUID
    let date: Date
    let origin: String
    let destination: String
    let distance: Decimal
    let unit: DistanceUnit
    let ratePerUnit: Decimal
    let amount: Decimal
    let currency: String
    let purpose: String
    let isBusiness: Bool
}

enum MileageAPIError: Error, Equatable {
    case http(Int)
    case invalidResponse
}

/// Reads and writes mileage trips through PostgREST with the signed-in session.
///
/// Logging and deleting go through the `money_log_mileage_trip` and
/// `money_delete_mileage_trip` functions, which write the trip and its expense
/// transaction together, so neither can exist without the other.
struct MileageAPI: Sendable {
    let session: BackendSession

    static let posix = Locale(identifier: "en_US_POSIX")

    /// Newest first. Enough to cover a UK tax year of business driving, which
    /// the 10,000-mile band is counted over.
    func trips(limit: Int = 500) async throws -> [MileageTrip] {
        var components = URLComponents(
            url: session.supabaseURL.appending(path: "rest/v1/money_mileage_trips"),
            resolvingAgainstBaseURL: false
        )
        var query = [
            URLQueryItem(
                name: "select",
                value: "id,trip_date,origin,destination,distance::text,unit,rate_per_unit::text,currency,purpose,scope,transaction:money_transactions(amount::text)"
            ),
            URLQueryItem(name: "deleted_at", value: "is.null"),
            URLQueryItem(name: "order", value: "trip_date.desc,created_at.desc"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let userID = await session.userID {
            query.append(URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"))
        }
        components?.queryItems = query
        guard let url = components?.url else { throw MileageAPIError.invalidResponse }

        let data = try await send(URLRequest(url: url))
        return try JSONDecoder().decode([MileageTrip].self, from: data)
    }

    func log(_ trip: NewMileageTrip) async throws {
        let body: [String: String] = [
            "p_id": trip.id.uuidString.lowercased(),
            "p_trip_date": Self.day(from: trip.date),
            "p_origin": trip.origin,
            "p_destination": trip.destination,
            "p_distance": Self.text(trip.distance),
            "p_unit": trip.unit.rawValue,
            "p_rate_per_unit": Self.text(trip.ratePerUnit),
            "p_amount": Self.text(trip.amount),
            "p_currency": trip.currency,
            "p_purpose": trip.purpose,
            "p_scope": trip.isBusiness ? "business" : "personal"
        ]
        _ = try await rpc("money_log_mileage_trip", body: body)
    }

    func delete(_ id: UUID) async throws {
        _ = try await rpc("money_delete_mileage_trip", body: ["p_id": id.uuidString.lowercased()])
    }

    // MARK: - Plumbing

    private func rpc(_ name: String, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: session.supabaseURL.appending(path: "rest/v1/rpc/\(name)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue(session.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try await session.accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MileageAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw MileageAPIError.http(http.statusCode) }
        return data
    }

    /// Plain decimal text with a dot, whatever the device's locale.
    static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: posix)
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.calendar = Calendar(identifier: .gregorian)
        // A trip date is a calendar day where the user is, not an instant.
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func day(from date: Date) -> String { dayFormatter.string(from: date) }
    static func date(fromDay day: String) -> Date? { dayFormatter.date(from: day) }
}
