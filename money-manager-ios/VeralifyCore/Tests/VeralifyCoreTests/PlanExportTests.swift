import Testing
import Foundation
@testable import VeralifyCore

@Suite("Plan export")
struct PlanExportTests {

    private let debts = [
        Debt(id: 1, name: "Court", balance: 3000, apr: 0, minimumPayment: 500),
        Debt(id: 2, name: "Intesa", balance: Decimal(string: "6491.72")!,
             apr: Decimal(string: "11.49")!, minimumPayment: Decimal(string: "177.98")!)
    ]

    private func plan() -> PayoffPlan {
        DebtPayoffEngine.plan(
            debts: debts, monthlyIncome: 4000, monthlyExpenses: 1200,
            targetMonths: 12, startDate: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    @Test("One header row, then one row per month of the route")
    func shapeMatchesTheRoute() {
        let plan = plan()
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let lines = PlanExport.csv(plan: plan, steps: steps).split(separator: "\n")

        #expect(lines.count == steps.count + 1)
        #expect(String(lines[0]) == PlanExport.headers.joined(separator: ","))
    }

    @Test("Every row has a field for every column")
    func everyRowIsComplete() {
        let plan = plan()
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)

        for line in PlanExport.csv(plan: plan, steps: steps).split(separator: "\n") {
            #expect(line.split(separator: ",", omittingEmptySubsequences: false).count
                    == PlanExport.headers.count)
        }
    }

    /// The whole reason to export: the columns have to add up in a spreadsheet.
    @Test("Amounts carry no symbol, grouping or locale decimal mark")
    func numbersAreMachineReadable() {
        #expect(PlanExport.number(1750) == "1750")
        #expect(PlanExport.number(Decimal(string: "1234.5")!) == "1234.5")
        #expect(PlanExport.number(Decimal(string: "0.005")!) == "0.01")
        #expect(!PlanExport.number(1750).contains(","))
        #expect(!PlanExport.number(1750).contains("€"))
    }

    /// A debt called "Mum, personal loan" would otherwise split into two
    /// columns and shift every figure on that row one place left.
    @Test("A comma in a name is quoted rather than allowed to split the row")
    func commasAreQuoted() {
        let line = PlanExport.row(["2026-09", "Mum, personal loan"])

        #expect(line == "2026-09,\"Mum, personal loan\"")
    }

    @Test("A quote in a name is doubled, as CSV requires")
    func quotesAreDoubled() {
        #expect(PlanExport.escaped("the \"big\" one") == "\"the \"\"big\"\" one\"")
    }

    @Test("Ordinary fields are left alone")
    func plainFieldsAreUntouched() {
        #expect(PlanExport.escaped("Court") == "Court")
        #expect(PlanExport.escaped("2026-09") == "2026-09")
    }

    @Test("The month a debt clears names it")
    func clearedDebtsAreNamed() {
        let plan = plan()
        let steps = JourneyBuilder.steps(plan: plan, debts: debts)
        let csv = PlanExport.csv(plan: plan, steps: steps)

        #expect(csv.contains("Court"))
        #expect(csv.contains("Intesa"))
    }

    @Test("A plan with no route exports its headings and nothing else")
    func emptyPlanIsJustHeadings() {
        let empty = DebtPayoffEngine.plan(
            debts: [], monthlyIncome: 4000, monthlyExpenses: 1200,
            targetMonths: 12, startDate: Date(timeIntervalSince1970: 1_790_000_000)
        )

        #expect(PlanExport.csv(plan: empty, steps: []) == PlanExport.headers.joined(separator: ","))
    }
}
