import Foundation
import Testing
@testable import MoneyManager

/// The amount fields are free text, and the keypad the user gets depends on
/// their locale — an Arabic keyboard can produce Arabic-Indic digits and the
/// Arabic decimal separator. Parsing has to survive all of it, because a
/// silently mis-parsed amount becomes a wrong payoff plan.
struct AmountParserTests {

    @Test("Plain digits parse")
    func plainDigits() {
        #expect(AmountParser.parse("3200") == 3200)
        #expect(AmountParser.parse("0") == 0)
    }

    @Test("A period decimal separator parses")
    func periodSeparator() {
        #expect(AmountParser.parse("19.9") == Decimal(string: "19.9"))
        #expect(AmountParser.parse("1234.56") == Decimal(string: "1234.56"))
    }

    @Test("A comma decimal separator parses as a decimal, not a thousands mark")
    func commaSeparator() {
        // European keypads offer a comma. Treating it as a grouping separator
        // would turn 19,9 into 199 — a tenfold error in an interest rate.
        #expect(AmountParser.parse("19,9") == Decimal(string: "19.9"))
    }

    @Test("Arabic-Indic digits and the Arabic decimal separator parse")
    func arabicNumerals() {
        #expect(AmountParser.parse("٣٢٠٠") == 3200)
        #expect(AmountParser.parse("١٩٫٩") == Decimal(string: "19.9"))
    }

    @Test("Surrounding whitespace is ignored")
    func whitespace() {
        #expect(AmountParser.parse("  500  ") == 500)
    }

    @Test("Empty, negative and non-numeric input is rejected")
    func rejectsUnusableInput() {
        #expect(AmountParser.parse("") == nil)
        #expect(AmountParser.parse("   ") == nil)
        #expect(AmountParser.parse("-50") == nil)
        #expect(AmountParser.parse("abc") == nil)
        #expect(AmountParser.parse("€") == nil)
    }
}

/// Due days drive the alerts screen. A silently rejected day means an alert
/// that never fires; a silently accepted bad one means a date that cannot exist.
struct DayParserTests {

    @Test("Valid days parse")
    func validDays() {
        #expect(DayParser.parse("1") == 1)
        #expect(DayParser.parse("25") == 25)
        #expect(DayParser.parse("31") == 31)
    }

    @Test("Arabic-Indic digits parse")
    func arabicDigits() {
        #expect(DayParser.parse("٢٥") == 25)
    }

    @Test("Out-of-range and empty values are rejected rather than clamped")
    func rejectsOutOfRange() {
        #expect(DayParser.parse("0") == nil)
        #expect(DayParser.parse("32") == nil)
        #expect(DayParser.parse("") == nil)
        #expect(DayParser.parse("abc") == nil)
        #expect(DayParser.parse("-5") == nil)
    }

    @Test("A decimal day truncates rather than being rejected")
    func truncatesDecimals() {
        // The number pad should not produce this, but a paste can.
        #expect(DayParser.parse("15.7") == 15)
    }
}
