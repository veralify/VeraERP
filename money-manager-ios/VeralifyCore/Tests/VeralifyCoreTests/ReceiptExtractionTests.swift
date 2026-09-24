import Testing
import Foundation
@testable import VeralifyCore

/// `receipt-extraction-v1.json` is produced by the gateway's own route (a
/// gateway test fails if it stops matching), so decoding it here checks the
/// app against what the server really sends.
@Suite("Receipt extraction")
struct ReceiptExtractionTests {

    static func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "receipt-extraction-v1", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("Decodes the gateway's response")
    func decodesFixture() throws {
        let e = try ReceiptExtraction.decode(Self.fixture())
        #expect(e.version == "1")
        #expect(e.receiptID == UUID(uuidString: "33333333-3333-4333-8333-333333333333"))
        #expect(e.documentType == .scontrino)
        #expect(e.merchant.name.value == "ESSELUNGA S.p.A.")
        #expect(e.merchant.vatID.value == "IT04916380159")
        #expect(e.merchantKey == "esselunga")
        #expect(e.date.value == "2026-09-20")
        #expect(e.currencyCode == "EUR")
        #expect(e.totalAmount == Decimal(string: "12.5"))
        #expect(e.taxLines.count == 2)
        #expect(e.taxLines.first?.rate == "10")
        #expect(e.lineItems.count == 3)
        #expect(e.lineItems[2].unitPrice == "4.50")
        #expect(e.payment.method.value == .card)
        #expect(e.payment.cardLast4.value == "1234")
        #expect(e.category.key == "groceries")
        #expect(e.category.source == .model)
        #expect(e.scopeSuggestion == .personal)
        #expect(e.duplicateOf == UUID(uuidString: "44444444-4444-4444-8444-444444444444"))
        #expect(e.promptVersion == "receipts-v1")
    }

    @Test("Flags low-confidence fields, not absent optional ones")
    func confidenceFlags() throws {
        let e = try ReceiptExtraction.decode(Self.fixture())
        // Tax total was read at 0.6; subtotal and tip are simply not printed.
        #expect(e.lowConfidenceFields == [.taxTotal])
        #expect(e.taxTotal.isLowConfidence)
        #expect(!e.total.isLowConfidence)
        #expect(e.needsAttention, "a likely duplicate needs a look")
    }

    @Test("A missing total is flagged even at zero confidence")
    func missingRequiredField() throws {
        var e = try ReceiptExtraction.decode(Self.fixture())
        e.total = ReceiptField(value: nil, confidence: 0)
        #expect(e.lowConfidenceFields.contains(.total))
        #expect(e.totalAmount == nil)
    }

    @Test("Tax falls back to the sum of the tax lines")
    func taxAmount() throws {
        var e = try ReceiptExtraction.decode(Self.fixture())
        #expect(e.taxAmount == Decimal(string: "1.07"))
        e.taxTotal = ReceiptField(value: nil, confidence: 0)
        #expect(e.taxAmount == Decimal(string: "1.07"))  // 0.44 + 0.63
        e.taxLines = []
        #expect(e.taxAmount == nil)
    }

    @Test("Date and time become one instant in the given zone")
    func occurredAt() throws {
        let e = try ReceiptExtraction.decode(Self.fixture())
        let rome = try #require(TimeZone(identifier: "Europe/Rome"))
        let date = try #require(e.occurredAt(in: rome))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rome
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 20)
        #expect(parts.hour == 18 && parts.minute == 42)

        var noTime = e
        noTime.time = ReceiptField(value: nil, confidence: 0)
        let midday = try #require(noTime.occurredAt(in: rome))
        #expect(calendar.component(.hour, from: midday) == 12)
    }

    @Test("Round-trips through encoding with nulls kept")
    func roundTrip() throws {
        let e = try ReceiptExtraction.decode(Self.fixture())
        let data = try e.encoded()
        #expect(try ReceiptExtraction.decode(data) == e)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""subtotal":{"confidence":0,"value":null}"#))
        #expect(json.contains(#""receipt_id":"33333333-3333-4333-8333-333333333333""#))
    }

    @Test("Unknown enum values and warnings from a newer server do not break decoding")
    func lenient() throws {
        var object = try #require(JSONSerialization.jsonObject(with: Self.fixture()) as? [String: Any])
        object["document_type"] = "e_ticket"
        object["warnings"] = ["total_mismatch", "handwritten"]
        object["scope_suggestion"] = "charity"
        let e = try ReceiptExtraction.decode(JSONSerialization.data(withJSONObject: object))
        #expect(e.documentType == .other)
        #expect(e.warnings == [.totalMismatch])
        #expect(e.scopeSuggestion == nil)
    }

    @Test("Refuses a version it does not know")
    func unknownVersion() throws {
        var object = try #require(JSONSerialization.jsonObject(with: Self.fixture()) as? [String: Any])
        object["version"] = "2"
        #expect(throws: ReceiptExtractionError.unsupportedVersion("2")) {
            try ReceiptExtraction.decode(JSONSerialization.data(withJSONObject: object))
        }
    }
}
