import Foundation
import Testing
@testable import VeralifyCore

/// Pins the Swift payoff engine against the web implementation.
///
/// Fixtures in `Fixtures/payoff-parity.json` are produced by
/// `Tools/generate-parity-fixtures.mjs`, which runs the real `server.js`
/// algorithm. Regenerate them whenever the web payoff logic changes; a failure
/// here means the two products would quote a user different payoff schedules.
struct PayoffParityTests {

    /// The web engine rounds every reported figure to two decimals, so
    /// agreement to one cent is the tightest meaningful assertion. The web side
    /// computes in binary floating point and this engine in decimal, so exact
    /// equality is not expected — but drift beyond a cent is a real defect.
    static let tolerance = Decimal(0.01)

    @Test("Swift engine matches the web engine", arguments: try Fixtures.load().scenarios)
    func matchesWebImplementation(_ scenario: Fixtures.Scenario) throws {
        let plan = DebtPayoffEngine.plan(
            debts: scenario.input.debts.map(\.asDebt),
            monthlyIncome: scenario.input.income,
            monthlyExpenses: scenario.input.expenses,
            targetMonths: scenario.input.targetMonths,
            startDate: try #require(Fixtures.date(scenario.input.startDate)),
            calendar: .gregorianUTC
        )

        expectClose(plan.requiredMonthly, scenario.expected.requiredMonthly, "requiredMonthly", scenario)
        expectClose(plan.usedMonthly, scenario.expected.usedMonthly, "usedMonthly", scenario)
        expectClose(plan.projectedRemaining, scenario.expected.projectedRemaining, "projectedRemaining", scenario)

        #expect(
            plan.isFeasible == scenario.expected.feasible,
            "\(scenario.name): feasibility disagrees — Swift \(plan.isFeasible), web \(scenario.expected.feasible)"
        )

        #expect(
            plan.months.count == scenario.expected.months.count,
            "\(scenario.name): schedule length \(plan.months.count) vs web \(scenario.expected.months.count)"
        )

        for (actual, expected) in zip(plan.months, scenario.expected.months) {
            #expect(
                actual.month == expected.month,
                "\(scenario.name): month key \(actual.month) vs web \(expected.month)"
            )
            expectClose(actual.totalPayment, expected.totalPayment, "\(expected.month) totalPayment", scenario)
            expectClose(actual.remainingDebt, expected.remainingDebt, "\(expected.month) remainingDebt", scenario)
            expectClose(actual.interestAccrued, expected.interestAccrued, "\(expected.month) interest", scenario)

            for (debtID, amount) in actual.payments {
                let webAmount = expected.payments[String(debtID)] ?? 0
                expectClose(amount, webAmount, "\(expected.month) payment to debt \(debtID)", scenario)
            }
        }
    }

    private func expectClose(
        _ actual: Decimal,
        _ expected: Decimal,
        _ label: String,
        _ scenario: Fixtures.Scenario,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let delta = abs(actual - expected)
        #expect(
            delta <= Self.tolerance,
            """
            \(scenario.name) / \(label): drifted from the web engine by \(delta.debugAmount)
              swift: \(actual.debugAmount)
              web:   \(expected.debugAmount)
              (\(scenario.note))
            """,
            sourceLocation: sourceLocation
        )
    }
}

enum Fixtures {
    struct Root: Decodable { let scenarios: [Scenario] }

    struct Scenario: Decodable, CustomTestStringConvertible {
        let name: String
        let note: String
        let input: Input
        let expected: Expected
        var testDescription: String { name }
    }

    struct Input: Decodable {
        let income: Decimal
        let expenses: Decimal
        let targetMonths: Int
        let startDate: String
        let debts: [FixtureDebt]
    }

    struct FixtureDebt: Decodable {
        let id: Int
        let name: String
        let balance: Decimal
        let apr: Decimal
        let minimumPayment: Decimal
        let priority: Int

        enum CodingKeys: String, CodingKey {
            case id, name, balance, apr, priority
            case minimumPayment = "minimum_payment"
        }

        var asDebt: Debt {
            Debt(
                id: id,
                name: name,
                balance: balance,
                apr: apr,
                minimumPayment: minimumPayment,
                priority: priority
            )
        }
    }

    struct Expected: Decodable {
        let requiredMonthly: Decimal
        let feasible: Bool
        let usedMonthly: Decimal
        let projectedRemaining: Decimal
        let months: [ExpectedMonth]
    }

    struct ExpectedMonth: Decodable {
        let month: String
        let payments: [String: Decimal]
        let totalPayment: Decimal
        let interestAccrued: Decimal
        let remainingDebt: Decimal
    }

    static func load() throws -> Root {
        let url = try #require(
            Bundle.module.url(forResource: "payoff-parity", withExtension: "json"),
            "payoff-parity.json missing — run: node Tools/generate-parity-fixtures.mjs"
        )
        return try JSONDecoder().decode(Root.self, from: Data(contentsOf: url))
    }

    static func date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = .gregorianUTC
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
