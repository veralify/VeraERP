import Foundation
import VeralifyCore

/// The receipt calls to Supabase: PostgREST for rows, Storage for pages, and
/// the AI gateway's `receipts-extract`. See docs/RECEIPTS_CONTRACTS.md §5.
///
/// Plain `URLSession` against `Backend.session`, which owns sign-in and token
/// refresh. A value type holding only the session, so its calls run off the
/// main actor and can be awaited from the queue without blocking the UI.
struct ReceiptAPI: Sendable {
    let session: BackendSession

    enum APIError: Error, Equatable {
        /// No connection, or it dropped: the queue waits for the network.
        case offline
        /// The gateway answered with one of its contract errors.
        case gateway(ReceiptGatewayError)
        /// PostgREST or Storage refused, with the HTTP status.
        case http(Int, String)
        case signedOut
    }

    @MainActor
    static func current() throws -> ReceiptAPI {
        ReceiptAPI(session: try Backend.require())
    }

    // MARK: Requests

    private func makeRequest(
        _ path: String,
        query: [URLQueryItem] = [],
        method: String,
        contentType: String? = "application/json",
        prefer: String? = nil
    ) async throws -> URLRequest {
        var components = URLComponents(
            url: session.supabaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.http(0, "Bad URL") }

        let token: String
        do {
            token = try await session.accessToken()
        } catch {
            throw APIError.signedOut
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(session.anonKey, forHTTPHeaderField: "apikey")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        return request
    }

    private func send(_ request: URLRequest, body: Data? = nil) async throws -> (Data, Int) {
        do {
            let result: (Data, URLResponse)
            if let body {
                result = try await URLSession.shared.upload(for: request, from: body)
            } else {
                result = try await URLSession.shared.data(for: request)
            }
            return (result.0, (result.1 as? HTTPURLResponse)?.statusCode ?? 0)
        } catch is URLError {
            // Every transport failure is "try again when online" to the queue:
            // each step is idempotent, so repeating it is safe.
            throw APIError.offline
        }
    }

    private static func json(_ object: [String: Any?]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object.mapValues { $0 ?? NSNull() })
    }

    private static func message(_ data: Data) -> String {
        String(data: data.prefix(300), encoding: .utf8) ?? ""
    }

    // MARK: Receipt row

    /// Creates the `money_receipts` row with the client's own id.
    ///
    /// A plain insert, not an upsert: the client has no update grant on
    /// `user_id`, so `on conflict do update` would be refused. A duplicate
    /// (409) means an earlier attempt got through, which is success.
    func createReceipt(id: UUID, userID: UUID, source: String) async throws {
        var request = try await makeRequest("rest/v1/money_receipts", method: "POST", prefer: "return=minimal")
        request.httpBody = try Self.json([
            "id": id.uuidString.lowercased(),
            "user_id": userID.uuidString.lowercased(),
            "source": source,
            "image_paths": [String]()
        ])
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) || status == 409 else {
            throw APIError.http(status, Self.message(data))
        }
    }

    /// Records the uploaded page paths, which tells the gateway the receipt
    /// is complete.
    func saveImagePaths(receiptID: UUID, paths: [String]) async throws {
        var request = try await makeRequest(
            "rest/v1/money_receipts",
            query: [URLQueryItem(name: "id", value: "eq.\(receiptID.uuidString.lowercased())")],
            method: "PATCH",
            prefer: "return=minimal"
        )
        request.httpBody = try Self.json(["image_paths": paths])
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) else { throw APIError.http(status, Self.message(data)) }
    }

    /// Soft delete (contract §2): the row stays so other devices learn of it.
    func deleteReceipt(id: UUID, at date: Date) async throws {
        var request = try await makeRequest(
            "rest/v1/money_receipts",
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")],
            method: "PATCH",
            prefer: "return=minimal"
        )
        request.httpBody = try Self.json(["deleted_at": ISO8601DateFormatter().string(from: date)])
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) else { throw APIError.http(status, Self.message(data)) }
    }

    // MARK: Storage

    /// Uploads one page to the private `receipts` bucket.
    func uploadPage(_ data: Data, path: String) async throws {
        let request = try await makeRequest(
            "storage/v1/object/\(ReceiptStorage.bucket)/\(path)",
            method: "POST",
            contentType: "image/jpeg"
        )
        let (body, status) = try await send(request, body: data)
        if (200..<300).contains(status) { return }
        // The object is already there from an attempt whose answer was lost.
        // VERIFY: Storage reports an existing object as HTTP 409 on current
        // versions and as 400 with `"statusCode":"409"` / "Duplicate" on older ones.
        let text = Self.message(body)
        if status == 409 || text.contains("\"409\"") || text.localizedCaseInsensitiveContains("duplicate") {
            return
        }
        throw APIError.http(status, text)
    }

    /// Fetches a page this phone does not have (captured elsewhere, or e-mailed).
    func downloadPage(path: String) async throws -> Data {
        let request = try await makeRequest(
            "storage/v1/object/authenticated/\(ReceiptStorage.bucket)/\(path)",
            method: "GET",
            contentType: nil
        )
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) else { throw APIError.http(status, Self.message(data)) }
        return data
    }

    // MARK: Gateway

    /// Asks the gateway to read the receipt. Returns the extraction and the
    /// raw JSON, which is stored verbatim.
    func extract(receiptID: UUID, locale: String, homeCurrency: String) async throws -> (ReceiptExtraction, Data) {
        var request = try await makeRequest("functions/v1/ai-gateway/receipts-extract", method: "POST")
        // Reading a long receipt can take the model most of a minute, and the
        // gateway tries up to three models before it gives up.
        request.timeoutInterval = 120
        request.httpBody = try Self.json([
            "receipt_id": receiptID.uuidString.lowercased(),
            "locale": locale,
            "home_currency": homeCurrency
        ])
        let (data, status) = try await send(request)
        guard status == 200 else {
            throw APIError.gateway(ReceiptGatewayError(status: status, body: data))
        }
        do {
            return (try ReceiptExtraction.decode(data), data)
        } catch {
            throw APIError.http(status, "Unreadable response: \(error)")
        }
    }

    // MARK: Merchant rules

    /// Remembers the user's category for a merchant, so the gateway files the
    /// next receipt from it the same way (contract §5, step 4).
    ///
    /// Looked up by key and then updated by id, rather than upserted on
    /// `(user_id, merchant_key)`: that unique index is partial (live rows
    /// only), and PostgREST's `on_conflict` cannot name a partial index.
    func saveMerchantRule(userID: UUID, merchantKey: String, categoryKey: String, scope: String?) async throws {
        let lookup = try await makeRequest(
            "rest/v1/money_merchant_rules",
            query: [
                URLQueryItem(name: "select", value: "id,hits"),
                URLQueryItem(name: "merchant_key", value: "eq.\(merchantKey)"),
                URLQueryItem(name: "deleted_at", value: "is.null"),
                URLQueryItem(name: "limit", value: "1")
            ],
            method: "GET",
            contentType: nil
        )
        let (found, lookupStatus) = try await send(lookup)
        guard (200..<300).contains(lookupStatus) else { throw APIError.http(lookupStatus, Self.message(found)) }

        struct Rule: Decodable {
            let id: UUID
            let hits: Int
        }
        let existing = (try? JSONDecoder().decode([Rule].self, from: found))?.first

        var request: URLRequest
        if let existing {
            request = try await makeRequest(
                "rest/v1/money_merchant_rules",
                query: [URLQueryItem(name: "id", value: "eq.\(existing.id.uuidString.lowercased())")],
                method: "PATCH",
                prefer: "return=minimal"
            )
            request.httpBody = try Self.json([
                "category_key": categoryKey,
                "scope": scope,
                "hits": existing.hits + 1
            ])
        } else {
            request = try await makeRequest("rest/v1/money_merchant_rules", method: "POST", prefer: "return=minimal")
            request.httpBody = try Self.json([
                "id": UUID().uuidString.lowercased(),
                "user_id": userID.uuidString.lowercased(),
                "merchant_key": merchantKey,
                "category_key": categoryKey,
                "scope": scope
            ])
        }
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) else { throw APIError.http(status, Self.message(data)) }
    }
}
