import Testing
import Foundation
@testable import VeralifyCore

@Suite("Mileage")
struct MileageTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private let band = MileagePresetBand.uk

    @Test("A flat rate is distance times rate, rounded to cents")
    func flatRate() {
        let result = Mileage.amount(distance: 10, unit: .km, rate: Decimal(string: "0.4521")!)
        #expect(result.amount == Decimal(string: "4.52")!)
        #expect(result.effectiveRate == Decimal(string: "0.4521")!)
    }

    @Test("UK car: 45p a mile inside the first 10,000 business miles")
    func insideBand() {
        let result = Mileage.amount(distance: 42, unit: .mi, rate: Decimal(string: "0.45")!, band: band, priorBusinessMiles: 0)
        #expect(result.amount == Decimal(string: "18.90")!)
        #expect(result.milesAfterBand == 0)
    }

    @Test("A trip that crosses 10,000 miles is split between the two rates")
    func crossingBand() {
        let result = Mileage.amount(distance: 100, unit: .mi, rate: Decimal(string: "0.45")!, band: band, priorBusinessMiles: 9_950)
        // 50 × 0.45 + 50 × 0.25
        #expect(result.amount == 35)
        #expect(result.milesAfterBand == 50)
        #expect(result.effectiveRate == Decimal(string: "0.35")!)
    }

    @Test("Past the limit every mile is at 25p")
    func afterBand() {
        let result = Mileage.amount(distance: 100, unit: .mi, rate: Decimal(string: "0.45")!, band: band, priorBusinessMiles: 12_000)
        #expect(result.amount == 25)
    }

    @Test("Personal trips neither use nor are limited by the band")
    func personalTrip() {
        let result = Mileage.amount(distance: 100, unit: .mi, rate: Decimal(string: "0.45")!, band: band, priorBusinessMiles: 12_000, isBusiness: false)
        #expect(result.amount == 45)
    }

    @Test("A banded trip logged in km is priced per mile")
    func kilometresInBand() {
        let result = Mileage.amount(distance: Decimal(string: "160.9344")!, unit: .km, rate: Decimal(string: "0.45")!, band: band)
        #expect(result.amount == 45)
        #expect(result.effectiveRate == Decimal(string: "0.2796")!)
    }

    @Test("Zero or negative input claims nothing")
    func invalidInput() {
        #expect(Mileage.amount(distance: 0, unit: .km, rate: 1).amount == 0)
        #expect(Mileage.amount(distance: 5, unit: .km, rate: -1).amount == 0)
    }

    @Test("The UK tax year starts on 6 April")
    func taxYear() {
        #expect(Mileage.ukTaxYearStart(containing: day(2026, 4, 5), calendar: calendar) == day(2025, 4, 6))
        #expect(Mileage.ukTaxYearStart(containing: day(2026, 4, 6), calendar: calendar) == day(2026, 4, 6))
        #expect(Mileage.ukTaxYearStart(containing: day(2027, 1, 10), calendar: calendar) == day(2026, 4, 6))
    }

    @Test("Prior miles count business trips in the same tax year only")
    func priorMiles() {
        let trips: [(date: Date, distance: Decimal, unit: DistanceUnit, isBusiness: Bool)] = [
            (day(2026, 4, 5), 500, .mi, true),        // previous tax year
            (day(2026, 5, 1), 100, .mi, true),
            (day(2026, 5, 2), Decimal(string: "160.9344")!, .km, true),
            (day(2026, 5, 3), 300, .mi, false),       // personal
            (day(2026, 9, 1), 1_000, .mi, true)       // after the trip
        ]
        let prior = Mileage.priorBusinessMiles(before: day(2026, 6, 1), trips: trips, calendar: calendar)
        #expect(prior == 200)
    }

    @Test("Presets carry the published defaults, and ask for a rate where there is none")
    func presets() {
        #expect(MileageRatePreset.ukCar.rate == Decimal(string: "0.45")!)
        #expect(MileageRatePreset.ukCar.band?.rateAfter == Decimal(string: "0.25")!)
        #expect(MileageRatePreset.ukCar.unit == .mi)
        #expect(MileageRatePreset.italyACI.rate == nil)
        #expect(MileageRatePreset.italyACI.currency == "EUR")
        #expect(Set(MileageRatePreset.all.map(\.id)).count == MileageRatePreset.all.count)
    }
}

private enum MileagePresetBand {
    static let uk = MileageBand(limitMiles: 10_000, rateAfter: Decimal(string: "0.25")!)
}
