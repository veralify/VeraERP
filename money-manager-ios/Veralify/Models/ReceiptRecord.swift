import Foundation
import SwiftData
import VeralifyCore

/// A photographed receipt, from capture to the transaction saved from it.
///
/// Mirrors `money_receipts` (docs/RECEIPTS_CONTRACTS.md §2 and §5). The
/// client writes only `id`, `image_paths`, `source`, `transaction_id` and
/// `deleted_at`; status and the AI's reading come back from the server. The
/// extra fields below the mirror are the phone's own bookkeeping for the
/// upload queue, so a receipt captured on a train resumes where it stopped.
///
/// Every property has a default so the store migrates without a mapping
/// model when this is added to an existing install.
@Model
final class ReceiptRecord {
    @Attribute(.unique) var id: UUID = UUID()

    /// `ReceiptStatus` raw value. Server statuses plus the phone's own
    /// `captured` / `uploading`, which precede them.
    var statusRaw: String = ReceiptStatus.captured.rawValue
    /// `money_receipt_source`: camera, photo_library, email, web_upload.
    var sourceRaw: String = "camera"

    /// Page files in Application Support/Receipts, in page order. Local only:
    /// the phone keeps its own copy so the review screen works offline and a
    /// failed upload can be retried without asking for the photo again.
    var localImageNames: [String] = []
    /// Storage object paths once uploaded: `{user_id}/{receipt_id}/{page}.jpg`.
    var imagePaths: [String] = []
    /// ReceiptExtraction v1 JSON, exactly as the gateway returned it.
    var extractionData: Data?
    /// The transaction confirmed from this receipt.
    var transactionID: UUID?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    /// Set when a client-writable column changed locally and the server has
    /// not seen it yet.
    var needsPush: Bool = true

    // MARK: Upload queue state (local only)

    /// Whether the `money_receipts` row exists on the server.
    var rowCreated: Bool = false
    /// Pages 1…n already in storage.
    var uploadedPageCount: Int = 0
    /// The last failure, as a `ReceiptGatewayError` code or a local one.
    var errorCode: String?
    var attemptCount: Int = 0
    /// When the queue may try again by itself; nil when it waits for the user.
    var nextAttemptAt: Date?

    /// A category correction to push to `money_merchant_rules`, kept here
    /// until it is sent so a correction made offline is not lost.
    var pendingRuleCategoryKey: String?
    var pendingRuleScopeRaw: String?

    init(
        id: UUID = UUID(),
        source: String = "camera",
        localImageNames: [String],
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceRaw = source
        self.localImageNames = localImageNames
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .captured }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    /// The decoded reading, or nil before it arrives (or if it is from a
    /// version of the contract this build does not know).
    var extraction: ReceiptExtraction? {
        extractionData.flatMap { try? ReceiptExtraction.decode($0) }
    }

    /// Whether a `money_receipts` row exists for it: created by this phone's
    /// queue, or pulled from the server (captured on another device, or
    /// e-mailed in), in which case it arrives with paths or a reading.
    var isKnownToServer: Bool {
        rowCreated || !imagePaths.isEmpty || extractionData != nil
    }

    var progress: ReceiptProgress {
        // A receipt that came from the server has no pages on this phone to
        // upload: everything up to the read is already done.
        if localImageNames.isEmpty && !imagePaths.isEmpty {
            return ReceiptProgress(
                status: status,
                rowCreated: true,
                pageCount: imagePaths.count,
                uploadedPages: imagePaths.count,
                pathsSaved: true
            )
        }
        return ReceiptProgress(
            status: status,
            rowCreated: isKnownToServer,
            pageCount: localImageNames.count,
            uploadedPages: uploadedPageCount,
            pathsSaved: !imagePaths.isEmpty && imagePaths.count == localImageNames.count
        )
    }
}
