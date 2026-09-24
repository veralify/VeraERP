import Foundation

/// Mileage allowances: what a business trip in your own vehicle can be claimed at.
///
/// Mirrors the web app's `mileage/_lib/mileage.ts`, so a trip logged on the
/// phone and one logged on the web are priced the same way. Keep them in step.
public enum DistanceUnit: String, Sendable, Codable, CaseIterable {
    case km
    case mi
}

/// A second rate after a yearly allowance of business miles — the UK car
/// band. Counted per UK tax year (from 6 April), business trips only.
public struct MileageBand: Sendable, Equatable {
    public let limitMiles: Decimal
    public let rateAfter: Decimal

    public init(limitMiles: Decimal, rateAfter: Decimal) {
        self.limitMiles = limitMiles
        self.rateAfter = rateAfter
    }
}

/// A starting point for the trip form. Every value stays editable: the rate
/// actually used is the one saved on the trip.
public struct MileageRatePreset: Sendable, Equatable, Identifiable {
    public let id: String
    public let currency: String
    public let unit: DistanceUnit
    /// Per `unit`, or nil when the user has to supply it.
    public let rate: Decimal?
    public let band: MileageBand?

    public init(id: String, currency: String, unit: DistanceUnit, rate: Decimal?, band: MileageBand? = nil) {
        self.id = id
        self.currency = currency
        self.unit = unit
        self.rate = rate
        self.band = band
    }

    // VERIFY: HMRC approved mileage allowance payments — cars and vans 45p a
    // mile for the first 10,000 business miles in the tax year, then 25p;
    // motorcycles 24p; bicycles 20p. Unchanged since 2011–12; check gov.uk
    // before each tax year.
    public static let ukCar = MileageRatePreset(
        id: "uk_car", currency: "GBP", unit: .mi, rate: Decimal(string: "0.45")!,
        band: MileageBand(limitMiles: 10_000, rateAfter: Decimal(string: "0.25")!)
    )
    public static let ukMotorcycle = MileageRatePreset(
        id: "uk_motorcycle", currency: "GBP", unit: .mi, rate: Decimal(string: "0.24")!
    )
    public static let ukBicycle = MileageRatePreset(
        id: "uk_bicycle", currency: "GBP", unit: .mi, rate: Decimal(string: "0.20")!
    )
    // VERIFY: Italy has no single statutory rate. The ACI publishes cost-per-km
    // tables by make, model and fuel each year, so the user enters their own.
    public static let italyACI = MileageRatePreset(id: "it_aci", currency: "EUR", unit: .km, rate: nil)
    public static let custom = MileageRatePreset(id: "custom", currency: "EUR", unit: .km, rate: nil)

    public static let all: [MileageRatePreset] = [ukCar, ukMotorcycle, ukBicycle, italyACI, custom]
}

public struct MileageAmount: Sendable, Equatable {
    /// The claim, rounded to cents.
    public let amount: Decimal
    /// The one per-unit rate that gives `amount` for this trip (four places);
    /// what is stored on the trip as `rate_per_unit`.
    public let effectiveRate: Decimal
    /// Miles of this trip charged at the band's second rate.
    public let milesAfterBand: Decimal
}

public enum Mileage {
    public static let kilometresPerMile = Decimal(string: "1.609344")!

    public static func miles(_ distance: Decimal, unit: DistanceUnit) -> Decimal {
        unit == .mi ? distance : distance / kilometresPerMile
    }

    /// The claim for one trip.
    ///
    /// With a band (UK cars), the band's rates are per mile whatever unit the
    /// trip was logged in, and a trip that crosses the limit is split: the part
    /// before it at `rate`, the rest at `band.rateAfter`. Personal trips do not
    /// use or count towards the band.
    public static func amount(
        distance: Decimal,
        unit: DistanceUnit,
        rate: Decimal,
        band: MileageBand? = nil,
        priorBusinessMiles: Decimal = 0,
        isBusiness: Bool = true
    ) -> MileageAmount {
        guard distance > 0, rate >= 0 else {
            return MileageAmount(amount: 0, effectiveRate: 0, milesAfterBand: 0)
        }
        guard let band, isBusiness else {
            return MileageAmount(amount: Money.rounded(distance * rate), effectiveRate: rate, milesAfterBand: 0)
        }

        let tripMiles = miles(distance, unit: unit)
        let remaining = Swift.max(0, band.limitMiles - Swift.max(0, priorBusinessMiles))
        let inBand = Swift.min(tripMiles, remaining)
        let after = tripMiles - inBand
        let amount = Money.rounded(inBand * rate + after * band.rateAfter)
        return MileageAmount(
            amount: amount,
            effectiveRate: rounded(amount / distance, places: 4),
            milesAfterBand: after
        )
    }

    /// Business miles already driven in the UK tax year of `date`, up to and
    /// including that day, from the trips the user has logged.
    public static func priorBusinessMiles(
        before date: Date,
        trips: [(date: Date, distance: Decimal, unit: DistanceUnit, isBusiness: Bool)],
        calendar: Calendar = .current
    ) -> Decimal {
        let start = ukTaxYearStart(containing: date, calendar: calendar)
        let end = calendar.startOfDay(for: date)
        return trips
            .filter { $0.isBusiness && calendar.startOfDay(for: $0.date) >= start && calendar.startOfDay(for: $0.date) <= end }
            .reduce(Decimal(0)) { $0 + miles($1.distance, unit: $1.unit) }
    }

    /// The start (6 April, midnight) of the UK tax year that contains `date`.
    public static func ukTaxYearStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2000
        let afterStart = (parts.month ?? 1, parts.day ?? 1) >= (4, 6)
        return calendar.date(from: DateComponents(year: afterStart ? year : year - 1, month: 4, day: 6))
            ?? calendar.startOfDay(for: date)
    }

    static func rounded(_ value: Decimal, places: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, places, .plain)
        return result
    }
}
