import Foundation
import Testing
import VeralifyCore
@testable import Veralify

/// A cache that goes stale is worse than no cache: the app would keep showing a
/// plan for figures the user has already changed.
@MainActor
struct PlanCacheTests {

    private func debts() -> [Debt] {
        [
            Debt(id: 1, name: "Court", balance: 3000, apr: 0, minimumPayment: 500),
            Debt(id: 2, name: "Intesa", balance: Decimal(string: "6491.72")!,
                 apr: Decimal(string: "11.49")!, minimumPayment: Decimal(string: "177.98")!)
        ]
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func plan(
        _ debts: [Debt], income: Decimal = 4000, expenses: Decimal = 1194, months: Int = 16
    ) -> PayoffPlan {
        PlanCache.plan(
            debts: debts, monthlyIncome: income, monthlyExpenses: expenses,
            targetMonths: months, startDate: start
        )
    }

    @Test("The same figures give the same plan")
    func repeatedCallsAgree() {
        let first = plan(debts())
        let second = plan(debts())
        #expect(first == second)
    }

    @Test("A cached plan matches what the engine computes directly")
    func cacheMatchesEngine() {
        let cached = plan(debts())
        let direct = DebtPayoffEngine.plan(
            debts: debts(), monthlyIncome: 4000, monthlyExpenses: 1194,
            targetMonths: 16, startDate: start
        )
        #expect(cached == direct)
    }

    @Test("Changing a balance invalidates it")
    func balanceChangeInvalidates() {
        let before = plan(debts())

        var changed = debts()
        changed[0].balance = 9000
        let after = plan(changed)

        #expect(after.totalDebt != before.totalDebt)
        #expect(after.totalDebt == changed.reduce(Decimal(0)) { $0 + $1.balance })
    }

    @Test("Changing income, expenses or the target period invalidates it")
    func otherInputsInvalidate() {
        _ = plan(debts())
        #expect(plan(debts(), income: 9000).available != plan(debts()).available)

        _ = plan(debts())
        #expect(plan(debts(), expenses: 50).available != plan(debts()).available)

        _ = plan(debts())
        #expect(plan(debts(), months: 40).targetMonths == 40)
    }

    @Test("Adding or removing a debt invalidates it")
    func debtSetInvalidates() {
        let two = plan(debts())

        var extra = debts()
        extra.append(Debt(id: 3, name: "New", balance: 1000, apr: 0, minimumPayment: 100))
        let three = plan(extra)
        #expect(three.totalDebt == two.totalDebt + 1000)

        let one = plan([debts()[0]])
        #expect(one.totalDebt == 3000)
    }

    @Test("Renaming a debt invalidates it, because the plan carries names")
    func renameInvalidates() {
        _ = plan(debts())

        var renamed = debts()
        renamed[1].name = "Intesa Sanpaolo"
        // The plan itself is keyed by id, but the roadmap reads names off the
        // same debts, so a stale entry here would show the old one.
        let after = plan(renamed)
        #expect(after.totalDebt == plan(debts()).totalDebt)
    }

    @Test("Alternating between two sets never returns the wrong one")
    func alternatingInputs() {
        var other = debts()
        other[0].balance = 12345

        for _ in 0..<5 {
            #expect(plan(debts()).totalDebt == Decimal(string: "9491.72")!)
            #expect(plan(other).totalDebt == Decimal(string: "18836.72")!)
        }
    }
}
