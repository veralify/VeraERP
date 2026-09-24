import Testing
import Foundation
@testable import VeralifyCore

@Suite("Receipt money")
struct ReceiptMoneyTests {

    struct Case: Decodable {
        let input: String
        let currency: String
        let money: String?
    }

    /// Shared with the gateway's `normaliseMoney` tests, so a figure typed on
    /// the review screen is read exactly as the gateway would read it.
    @Test("Matches the gateway on every shared case")
    func sharedCases() throws {
        let url = try #require(Bundle.module.url(forResource: "receipt_money_cases", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        #expect(cases.count >= 20)
        for item in cases {
            #expect(
                ReceiptMoney.canonical(item.input, currency: item.currency) == item.money,
                "\(item.input) \(item.currency)"
            )
        }
    }

    @Test("Canonical strings convert to Decimal exactly")
    func exactDecimal() {
        #expect(ReceiptMoney.decimal(fromCanonical: "12.50") == Decimal(string: "12.5"))
        #expect(ReceiptMoney.decimal(fromCanonical: "-2.00") == -2)
        #expect(ReceiptMoney.decimal(fromCanonical: "12,50") == nil)
        #expect(ReceiptMoney.decimal(fromCanonical: "1e3") == nil)
        #expect(ReceiptMoney.decimal(fromCanonical: "") == nil)
    }

    @Test("Amounts are sent in the currency's precision")
    func contractString() {
        #expect(ReceiptMoney.string(Decimal(string: "12.5")!) == "12.50")
        #expect(ReceiptMoney.string(Decimal(string: "0.005")!, currency: "EUR") == "0.01")
        #expect(ReceiptMoney.string(Decimal(string: "-4.2")!, currency: "GBP") == "-4.20")
        #expect(ReceiptMoney.string(1500, currency: "JPY") == "1500")
        #expect(ReceiptMoney.string(0) == "0.00")
        #expect(ReceiptMoney.string(Decimal(string: "1234567.891")!) == "1234567.89")
    }

    @Test("Typed amounts parse leniently")
    func lenientParse() {
        #expect(ReceiptMoney.parse("1.234,50") == Decimal(string: "1234.5"))
        #expect(ReceiptMoney.parse("£4.20", currency: "GBP") == Decimal(string: "4.2"))
        #expect(ReceiptMoney.parse("twelve") == nil)
    }

    @Test("Quantities and rates keep their decimals and drop trailing zeros")
    func decimals() {
        #expect(ReceiptMoney.canonicalDecimal("22,00") == "22")
        #expect(ReceiptMoney.canonicalDecimal("5.5") == "5.5")
        #expect(ReceiptMoney.canonicalDecimal("1,234") == "1.234")
        #expect(ReceiptMoney.canonicalDecimal("0") == "0")
    }
}
