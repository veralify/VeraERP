import Testing
import Foundation
@testable import VeralifyCore

/// Same fixtures and expectations as supabase/tests/money_fx.sql, so the
/// phone and the database agree on every conversion.
@Suite("Currency conversion")
struct CurrencyConversionTests {

    private let converter = CurrencyConverter(rates: [
        FXRate(day: "2026-09-17", quote: "USD", rate: Decimal(string: "1.16")!),
        FXRate(day: "2026-09-17", quote: "GBP", rate: Decimal(string: "0.86")!),
        FXRate(day: "2026-09-17", quote: "JPY", rate: 170),
        FXRate(day: "2026-09-18", quote: "USD", rate: Decimal(string: "1.17")!),
        FXRate(day: "2026-09-18", quote: "GBP", rate: Decimal(string: "0.85")!)
    ])

    @Test("Same currency is 1, with or without rates")
    func sameCurrency() {
        #expect(converter.rate(from: "EUR", to: "EUR", on: "2020-01-01") == 1)
        #expect(CurrencyConverter(rates: []).convert(100, from: "gbp", to: "GBP", on: "2026-09-18") == 100)
    }

    @Test("EUR to a quote is the published rate; codes are case-insensitive")
    func direct() {
        #expect(converter.rate(from: "eur", to: "usd", on: "2026-09-18") == Decimal(string: "1.17")!)
    }

    @Test("A weekend uses the latest earlier publication; never a later one")
    func nearestEarlier() {
        #expect(converter.rate(from: "EUR", to: "USD", on: "2026-09-20") == Decimal(string: "1.17")!)
        #expect(converter.rate(from: "EUR", to: "USD", on: "2026-09-17") == Decimal(string: "1.16")!)
    }

    @Test("Converting uses the inverse and cross rates through EUR, rounded to cents")
    func conversions() {
        #expect(converter.convert(117, from: "USD", to: "EUR", on: "2026-09-19") == 100)
        #expect(converter.convert(100, from: "USD", to: "EUR", on: "2026-09-18") == Decimal(string: "85.47")!)
        #expect(converter.convert(117, from: "USD", to: "GBP", on: "2026-09-18") == 85)
        #expect(converter.convert(Decimal(string: "12.50")!, from: "EUR", to: "GBP", on: "2026-09-18") == Decimal(string: "10.63")!)
    }

    @Test("Both legs of a cross rate come from the same day")
    func sameDayLegs() {
        // JPY was only published on the 17th, so USD comes from the 17th too.
        let rate = converter.rate(from: "JPY", to: "USD", on: "2026-09-18")
        #expect(rate == Decimal(string: "1.16")! / 170)
    }

    @Test("Missing, too old or unknown means nil, never a guess")
    func missing() {
        #expect(converter.rate(from: "EUR", to: "USD", on: "2026-09-10") == nil)
        #expect(converter.rate(from: "EUR", to: "USD", on: "2026-10-01") == nil)
        #expect(converter.rate(from: "EUR", to: "XAU", on: "2026-09-18") == nil)
        #expect(converter.convert(100, from: "USD", to: "EUR", on: "not-a-day") == nil)
        #expect(converter.rate(from: "EUR", to: "USD", on: "2026-09-25") == Decimal(string: "1.17")!, "7 days old is still fine")
    }
}
