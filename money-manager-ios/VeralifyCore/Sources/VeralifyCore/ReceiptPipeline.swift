import Foundation

/// Where a captured receipt is on its way from the camera to a saved
/// transaction.
///
/// The server's `money_receipts.status` has five values; the phone adds two
/// before them, because a receipt exists on the phone before the server has
/// heard of it (captured offline, or mid-upload). Raw values match the
/// server's where they overlap, so a pulled row maps straight across.
public enum ReceiptStatus: String, Codable, Sendable, CaseIterable {
    /// Saved on the phone, nothing sent yet — typically offline.
    case captured
    /// The row exists or is being created; pages are going up.
    case uploading
    /// Server: every page is in storage; not read yet.
    case uploaded
    /// Server: the AI is reading it.
    case processing
    /// Server: read, waiting for the user to check and confirm.
    case extracted
    /// Server: a transaction was saved from it.
    case confirmed
    /// Server: could not be read (or, on the phone, could not be sent).
    case failed

    /// The four states the list and the entry card talk about.
    public enum Phase: Sendable, Equatable {
        case uploading, reading, needsReview, done, failed
    }

    public var phase: Phase {
        switch self {
        case .captured, .uploading: .uploading
        case .uploaded, .processing: .reading
        case .extracted: .needsReview
        case .confirmed: .done
        case .failed: .failed
        }
    }

    /// Whether the queue still has work to do for a receipt in this state.
    public var isPending: Bool {
        switch self {
        case .captured, .uploading, .uploaded, .processing: true
        case .extracted, .confirmed, .failed: false
        }
    }
}

/// What the queue does next for one receipt. Pure, so the order — row, then
/// pages, then paths, then the read — is tested rather than trusted.
public enum ReceiptStep: Equatable, Sendable {
    case createRow
    case uploadPage(Int)
    case savePaths
    case read
    case nothing
}

public struct ReceiptProgress: Equatable, Sendable {
    public var status: ReceiptStatus
    public var rowCreated: Bool
    public var pageCount: Int
    /// Pages 1…n already in storage.
    public var uploadedPages: Int
    public var pathsSaved: Bool

    public init(status: ReceiptStatus, rowCreated: Bool, pageCount: Int, uploadedPages: Int, pathsSaved: Bool) {
        self.status = status
        self.rowCreated = rowCreated
        self.pageCount = pageCount
        self.uploadedPages = uploadedPages
        self.pathsSaved = pathsSaved
    }

    /// The row comes first because storage paths are checked against it on
    /// the server; the paths are saved only once every page is up, so the
    /// gateway never reads a receipt with a page missing.
    public var nextStep: ReceiptStep {
        guard status.isPending, pageCount > 0 else { return .nothing }
        if !rowCreated { return .createRow }
        if uploadedPages < pageCount { return .uploadPage(uploadedPages + 1) }
        if !pathsSaved { return .savePaths }
        return .read
    }
}

public enum ReceiptStorage {
    /// The private bucket every page goes to.
    public static let bucket = "receipts"

    /// `{user_id}/{receipt_id}/{page}.jpg`, page from 1.
    ///
    /// Lower-case on purpose. `UUID.uuidString` is upper-case, but Postgres
    /// prints a uuid in lower case: the storage policy compares the first
    /// folder with `auth.uid()::text`, and the gateway checks each path
    /// against the row's own ids — an upper-case path fails both.
    public static func path(userID: UUID, receiptID: UUID, page: Int) -> String {
        "\(userID.uuidString.lowercased())/\(receiptID.uuidString.lowercased())/\(page).jpg"
    }

    /// Longest edge sent, in pixels, and the JPEG quality — enough for the
    /// model to read 7pt thermal print, small enough to upload on 3G.
    public static let maxLongEdge: Double = 1600
    public static let jpegQuality: Double = 0.7

    /// The size to draw a page at before encoding: scaled down to fit
    /// `maxLongEdge`, never up, and in whole pixels.
    public static func targetSize(width: Double, height: Double, maxLongEdge: Double = maxLongEdge) -> (width: Double, height: Double) {
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge, longEdge > 0 else { return (width.rounded(), height.rounded()) }
        let scale = maxLongEdge / longEdge
        return (max(1, (width * scale).rounded()), max(1, (height * scale).rounded()))
    }
}

/// `receipts-extract` failures, from the contract's `{ "error": CODE }`.
public enum ReceiptGatewayError: Error, Equatable, Sendable {
    case unauthenticated
    case receiptNotFound
    case scanLimitReached
    case unreadable
    case aiUnavailable
    case rateLimited
    case busy
    case imagesMissing
    case badRequest(String)
    case server(status: Int)

    public init(status: Int, code: String?) {
        switch (status, code) {
        case (401, _): self = .unauthenticated
        case (404, _): self = .receiptNotFound
        case (402, _): self = .scanLimitReached
        case (422, _): self = .unreadable
        case (503, _): self = .aiUnavailable
        case (429, _): self = .rateLimited
        case (409, "RECEIPT_BUSY"): self = .busy
        case (400, "IMAGES_MISSING"): self = .imagesMissing
        case (400, _), (409, _): self = .badRequest(code ?? "BAD_REQUEST")
        default: self = .server(status: status)
        }
    }

    /// Parses the error body the gateway sends; falls back to the status alone.
    public init(status: Int, body: Data) {
        struct Body: Decodable { let error: String? }
        self.init(status: status, code: (try? JSONDecoder().decode(Body.self, from: body))?.error)
    }

    /// Stable code stored on the receipt, for the UI to explain.
    public var code: String {
        switch self {
        case .unauthenticated: "UNAUTHENTICATED"
        case .receiptNotFound: "RECEIPT_NOT_FOUND"
        case .scanLimitReached: "SCAN_LIMIT_REACHED"
        case .unreadable: "UNREADABLE"
        case .aiUnavailable: "AI_UNAVAILABLE"
        case .rateLimited: "RATE_LIMITED"
        case .busy: "RECEIPT_BUSY"
        case .imagesMissing: "IMAGES_MISSING"
        case .badRequest(let code): code
        case .server: "SERVER_ERROR"
        }
    }

    /// Whether the queue should try again by itself. An unreadable photo
    /// will be unreadable next time too, and the scan limit lasts the month:
    /// those wait for the user.
    public var retriesAutomatically: Bool {
        switch self {
        case .aiUnavailable, .rateLimited, .busy, .server: true
        case .unauthenticated, .receiptNotFound, .scanLimitReached, .unreadable, .imagesMissing, .badRequest: false
        }
    }
}

public enum ReceiptRetryPolicy {
    /// Waits after the n-th failed attempt (1-based): 30s, 2m, 10m, 1h, then
    /// hourly. Short at first because most failures are a blip; capped so a
    /// long outage does not leave a receipt waiting a day.
    public static func delay(afterAttempt attempt: Int) -> TimeInterval {
        let steps: [TimeInterval] = [30, 120, 600, 3600]
        return steps[min(max(attempt, 1), steps.count) - 1]
    }
}
