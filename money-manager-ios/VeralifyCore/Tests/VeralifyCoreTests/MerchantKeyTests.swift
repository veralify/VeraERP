import Testing
import Foundation
@testable import VeralifyCore

/// The same table the AI gateway's `merchantKey()` is tested against
/// (`supabase/functions/ai-gateway/tests/fixtures/merchant_keys.json`; a
/// gateway test fails if the two copies differ). A rule the app saves under
/// one key must be found by the gateway under the same key.
@Suite("Merchant key")
struct MerchantKeyTests {

    struct Example: Decodable {
        let name: String
        let key: String
    }

    static func examples() throws -> [Example] {
        let url = try #require(Bundle.module.url(forResource: "merchant_keys", withExtension: "json"))
        return try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
    }

    @Test("Matches every example in the shared table")
    func sharedTable() throws {
        let examples = try Self.examples()
        #expect(examples.count >= 20)
        for example in examples {
            #expect(MerchantKey.make(from: example.name) == example.key, "\(example.name)")
        }
    }

    @Test("The contract's own examples")
    func contractExamples() {
        #expect(MerchantKey.make(from: "ESSELUNGA S.p.A.") == "esselunga")
        #expect(MerchantKey.make(from: "Marks & Spencer PLC") == "marks and spencer")
    }

    @Test("A suffix only goes when it ends the name")
    func suffixPosition() {
        #expect(MerchantKey.make(from: "Spa Wellness Centre Ltd") == "spa wellness centre")
        #expect(MerchantKey.make(from: "Limited Edition Records") == "limited edition records")
    }

    @Test("Is stable when applied twice")
    func idempotent() throws {
        for example in try Self.examples() {
            // A key is itself a merchant name, and must map to itself: the
            // rules table is keyed on it and nothing re-normalises on lookup.
            let once = MerchantKey.make(from: example.name)
            #expect(MerchantKey.make(from: once) == once, "\(example.name)")
        }
    }
}
