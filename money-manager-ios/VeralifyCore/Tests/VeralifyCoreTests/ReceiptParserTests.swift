import Testing
import Foundation
@testable import VeralifyCore

@Suite("Receipt parsing")
struct ReceiptParserTests {

    // MARK: - Reading amounts off a line

    @Test("Reads a dot decimal, the US convention")
    func dotDecimal() {
        #expect(ReceiptParser.amounts(in: "TOTAL      42.50") == [Decimal(string: "42.50")!])
    }

    @Test("Reads a comma decimal, which is how the whole of Europe prints money")
    func commaDecimal() {
        // A parser that only knows the dot reads nothing at all off an Italian
        // receipt — every amount on it silently disappears.
        #expect(ReceiptParser.amounts(in: "TOTALE      42,50") == [Decimal(string: "42.50")!])
    }

    @Test("Reads both thousands conventions")
    func thousandsSeparators() {
        #expect(ReceiptParser.amounts(in: "TOTALE  1.234,56") == [Decimal(string: "1234.56")!])
        #expect(ReceiptParser.amounts(in: "TOTAL   1,234.56") == [Decimal(string: "1234.56")!])
    }

    @Test("Finds several amounts on one line, in order")
    func multipleOnOneLine() {
        let found = ReceiptParser.amounts(in: "2 x 7,50    15,00")
        #expect(found == [Decimal(string: "7.50")!, Decimal(string: "15.00")!])
    }

    @Test("Ignores text that is not money")
    func ignoresNonMoney() {
        #expect(ReceiptParser.amounts(in: "Tavolo 4  Coperti 3").isEmpty)
        #expect(ReceiptParser.amounts(in: "P.IVA 01234567890").isEmpty)
        #expect(ReceiptParser.amounts(in: "").isEmpty)
    }

    // MARK: - Finding the total

    /// A real Italian restaurant receipt, in the order the printer emits it.
    private let italian = [
        "TRATTORIA DA GINO",
        "Via Roma 14, Milano",
        "P.IVA 01234567890",
        "",
        "2 Margherita        16,00",
        "1 Bistecca          22,50",
        "3 Birra Media       13,50",
        "1 Tiramisu           6,00",
        "",
        "SUBTOTALE           58,00",
        "IVA 10%              5,80",
        "TOTALE EURO         63,80",
        "",
        "CONTANTI            70,00",
        "RESTO                6,20"
    ]

    @Test("Takes the total, not the subtotal")
    func skipsSubtotal() throws {
        // "SUBTOTALE" contains "totale". Matching the keyword without excluding
        // this first reads back the figure before tax — the single most likely
        // way to get this wrong.
        let total = try #require(ReceiptParser.findTotal(in: italian))
        #expect(total.amount == Decimal(string: "63.80")!)
        #expect(total.basis == .keyword)
    }

    @Test("Takes the total, not the cash handed over")
    func skipsCashTendered() throws {
        // CONTANTI 70,00 is larger than the total. A "largest amount wins"
        // parser would charge the table for the change.
        let total = try #require(ReceiptParser.findTotal(in: italian))
        #expect(total.amount != Decimal(string: "70.00")!)
    }

    @Test("Reads a US receipt")
    func americanReceipt() throws {
        let lines = [
            "THE CORNER DINER",
            "Burger              12.00",
            "Fries                4.50",
            "Soda                 2.75",
            "Subtotal            19.25",
            "Tax                  1.64",
            "TOTAL               20.89"
        ]
        let total = try #require(ReceiptParser.findTotal(in: lines))
        #expect(total.amount == Decimal(string: "20.89")!)
        #expect(total.basis == .keyword)
    }

    @Test("A later total line wins over an earlier one")
    func lastTotalWins() throws {
        let lines = [
            "TOTAL ITEMS          3",
            "Total               19.25",
            "Tip                  4.00",
            "Total Due           23.25"
        ]
        let total = try #require(ReceiptParser.findTotal(in: lines))
        #expect(total.amount == Decimal(string: "23.25")!)
    }

    @Test("With no total line, falls back to the largest amount and says so")
    func fallsBackToLargest() throws {
        // OCR misreads the total line often enough that giving up is worse
        // than guessing — but the guess has to be labelled as one.
        let lines = ["Coffee 3,50", "Cornetto 1,80", "5,30"]
        let total = try #require(ReceiptParser.findTotal(in: lines))
        #expect(total.amount == Decimal(string: "5.30")!)
        #expect(total.basis == .largestAmount)
    }

    @Test("A receipt with no money on it yields nothing rather than zero")
    func noAmounts() {
        #expect(ReceiptParser.findTotal(in: ["TRATTORIA DA GINO", "Grazie e arrivederci"]) == nil)
        #expect(ReceiptParser.findTotal(in: []) == nil)
    }

    @Test("Excluded keywords cannot be read as a total", arguments: [
        "SUBTOTAL 19.25", "Sub Total 19.25", "SOTTOTOTALE 19,25",
        "TOTALE IMPONIBILE 58,00", "Taxable 58.00"
    ])
    func excludedLines(_ line: String) {
        let total = ReceiptParser.findTotal(in: [line, "Nothing else here"])
        // It may still fall back to the amount, but never as a keyword match.
        #expect(total?.basis != .keyword)
    }

    @Test("Handles the case OCR usually produces: no alignment, stray characters")
    func messyOcr() throws {
        // Vision returns text without column alignment and drops the odd glyph.
        let lines = [
            "TRATTORIA DA GlNO",
            "2 Margherita 16,00",
            "SUBTOTALE 58,00",
            "IVA 10% 5,80",
            "TOTALE EURO 63,80"
        ]
        let total = try #require(ReceiptParser.findTotal(in: lines))
        #expect(total.amount == Decimal(string: "63.80")!)
    }

    @Test("The matched line comes back, so the UI can show its working")
    func reportsTheLine() throws {
        let total = try #require(ReceiptParser.findTotal(in: italian))
        #expect(total.line.contains("TOTALE"))
    }
}
