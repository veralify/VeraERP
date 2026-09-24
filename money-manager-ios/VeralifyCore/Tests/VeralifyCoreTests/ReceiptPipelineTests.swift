import Testing
import Foundation
@testable import VeralifyCore

@Suite("Receipt pipeline")
struct ReceiptPipelineTests {

    @Test("Row first, then every page, then the paths, then the read")
    func stepOrder() {
        var p = ReceiptProgress(status: .captured, rowCreated: false, pageCount: 2, uploadedPages: 0, pathsSaved: false)
        #expect(p.nextStep == .createRow)
        p.rowCreated = true
        #expect(p.nextStep == .uploadPage(1))
        p.uploadedPages = 1
        #expect(p.nextStep == .uploadPage(2))
        p.uploadedPages = 2
        #expect(p.nextStep == .savePaths)
        p.pathsSaved = true
        #expect(p.nextStep == .read)
    }

    @Test("Nothing to do once read, confirmed or failed, or with no pages")
    func settled() {
        for status in [ReceiptStatus.extracted, .confirmed, .failed] {
            let p = ReceiptProgress(status: status, rowCreated: true, pageCount: 1, uploadedPages: 1, pathsSaved: true)
            #expect(p.nextStep == .nothing)
        }
        let empty = ReceiptProgress(status: .captured, rowCreated: false, pageCount: 0, uploadedPages: 0, pathsSaved: false)
        #expect(empty.nextStep == .nothing)
    }

    @Test("Statuses group into what the user sees")
    func phases() {
        #expect(ReceiptStatus.captured.phase == .uploading)
        #expect(ReceiptStatus.processing.phase == .reading)
        #expect(ReceiptStatus.extracted.phase == .needsReview)
        #expect(ReceiptStatus.confirmed.phase == .done)
        // Raw values are the server's where they overlap.
        #expect(ReceiptStatus(rawValue: "extracted") == .extracted)
    }

    @Test("Storage paths are lower-case, as the policy and the gateway compare them")
    func storagePath() throws {
        let user = try #require(UUID(uuidString: "11111111-AAAA-4111-8111-111111111111"))
        let receipt = try #require(UUID(uuidString: "33333333-BBBB-4333-8333-333333333333"))
        #expect(
            ReceiptStorage.path(userID: user, receiptID: receipt, page: 2)
                == "11111111-aaaa-4111-8111-111111111111/33333333-bbbb-4333-8333-333333333333/2.jpg"
        )
    }

    @Test("Pages are scaled down to 1600 on the long edge, never up")
    func sizing() {
        let big = ReceiptStorage.targetSize(width: 3024, height: 4032)
        #expect(big.height == 1600)
        #expect(big.width == 1200)
        let small = ReceiptStorage.targetSize(width: 800, height: 1200)
        #expect(small.width == 800 && small.height == 1200)
        let wide = ReceiptStorage.targetSize(width: 4000, height: 10)
        #expect(wide.width == 1600 && wide.height == 4)
    }

    @Test("Gateway errors map from the contract's codes")
    func errors() {
        #expect(ReceiptGatewayError(status: 402, body: Data(#"{"error":"SCAN_LIMIT_REACHED","message":"x"}"#.utf8)) == .scanLimitReached)
        #expect(ReceiptGatewayError(status: 422, code: "UNREADABLE") == .unreadable)
        #expect(ReceiptGatewayError(status: 503, body: Data("not json".utf8)) == .aiUnavailable)
        #expect(ReceiptGatewayError(status: 409, code: "RECEIPT_BUSY") == .busy)
        #expect(ReceiptGatewayError(status: 400, code: "IMAGES_MISSING") == .imagesMissing)
        #expect(ReceiptGatewayError(status: 500, code: nil) == .server(status: 500))
        #expect(ReceiptGatewayError.aiUnavailable.retriesAutomatically)
        #expect(!ReceiptGatewayError.unreadable.retriesAutomatically)
        #expect(!ReceiptGatewayError.scanLimitReached.retriesAutomatically)
        #expect(ReceiptGatewayError.scanLimitReached.code == "SCAN_LIMIT_REACHED")
    }

    @Test("Retries back off and then hold at an hour")
    func backoff() {
        #expect(ReceiptRetryPolicy.delay(afterAttempt: 1) == 30)
        #expect(ReceiptRetryPolicy.delay(afterAttempt: 2) == 120)
        #expect(ReceiptRetryPolicy.delay(afterAttempt: 4) == 3600)
        #expect(ReceiptRetryPolicy.delay(afterAttempt: 40) == 3600)
        #expect(ReceiptRetryPolicy.delay(afterAttempt: 0) == 30)
    }
}
