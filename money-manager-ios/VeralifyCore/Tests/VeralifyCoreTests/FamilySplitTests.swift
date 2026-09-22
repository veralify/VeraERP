import Testing
import Foundation
@testable import VeralifyCore

@Suite("Family splits and balances")
struct FamilySplitTests {

    private let me = UUID()
    private let maria = UUID()
    private let sam = UUID()

    // MARK: - Equal shares

    @Test("An even split adds back up to the total")
    func evenSplitIsExact() {
        let shares = FamilySplit.equalShares(of: 90, among: [me, maria, sam])
        #expect(shares.values.reduce(Decimal(0), +) == 90)
        #expect(shares.values.allSatisfy { $0 == 30 })
    }

    @Test("A remainder is spread as whole cents, not lost")
    func remainderIsSpread() {
        // €10 three ways is 3.3333…; rounding each share loses a cent, and a
        // lost cent is a balance nobody can ever settle.
        let shares = FamilySplit.equalShares(of: 10, among: [me, maria, sam])

        #expect(shares.values.reduce(Decimal(0), +) == 10)
        #expect(shares.values.sorted() == [Decimal(string: "3.33")!, Decimal(string: "3.33")!, Decimal(string: "3.34")!])
    }

    @Test("Awkward amounts still reconcile exactly", arguments: [
        "0.01", "0.02", "7.77", "99.99", "1234.56", "2078.15"
    ])
    func awkwardAmountsReconcile(_ text: String) {
        let amount = Decimal(string: text)!
        for participants in [[me], [me, maria], [me, maria, sam]] {
            let shares = FamilySplit.equalShares(of: amount, among: participants)
            #expect(shares.values.reduce(Decimal(0), +) == amount, "\(text) among \(participants.count)")
        }
    }

    @Test("An N-way split adds back up to the total", arguments: [
        "10", "100", "0.01", "127.50", "87.41", "999.99"
    ])
    func nWaySplitIsExact(_ text: String) {
        let amount = Decimal(string: text)!
        for ways in 1...20 {
            let shares = FamilySplit.equalShares(of: amount, ways: ways)
            #expect(shares.count == ways)
            #expect(shares.reduce(Decimal(0), +) == amount, "\(text) split \(ways) ways")
        }
    }

    @Test("Shares differ by at most one cent, and the extra goes first")
    func nWaySplitSpreadsTheRemainder() {
        // €100 three ways is 33.34 / 33.33 / 33.33 — never 33.33 three times,
        // which would collect a cent short of the bill.
        let shares = FamilySplit.equalShares(of: 100, ways: 3)
        #expect(shares == [Decimal(string: "33.34")!, Decimal(string: "33.33")!, Decimal(string: "33.33")!])

        let spread = (shares.max() ?? 0) - (shares.min() ?? 0)
        #expect(spread <= Decimal(string: "0.01")!)
    }

    @Test("Both overloads round identically")
    func overloadsAgree() {
        let people = [UUID(), UUID(), UUID()]
        let byID = FamilySplit.equalShares(of: Decimal(string: "10")!, among: people)
        let byCount = FamilySplit.equalShares(of: Decimal(string: "10")!, ways: 3)

        #expect(byID.values.reduce(Decimal(0), +) == byCount.reduce(Decimal(0), +))
        #expect(Set(byID.values.map(\.description)) == Set(byCount.map(\.description)))
    }

    @Test("Splitting zero ways produces nothing rather than dividing by zero")
    func zeroWays() {
        #expect(FamilySplit.equalShares(of: 50, ways: 0).isEmpty)
    }

    @Test("Splitting among nobody produces nothing rather than crashing")
    func noParticipants() {
        #expect(FamilySplit.equalShares(of: 50, among: []).isEmpty)
    }

    // MARK: - Balances

    @Test("Paying for everyone lends them their share")
    func payerIsOwed() {
        let expense = SharedExpense(
            id: UUID(), amount: 90, paidBy: me,
            shares: FamilySplit.equalShares(of: 90, among: [me, maria, sam])
        )
        let net = FamilySplit.balances(expenses: [expense])

        #expect(net[me] == 60)       // paid 90, owed 30 of it
        #expect(net[maria] == -30)
        #expect(net[sam] == -30)
    }

    @Test("Balances always sum to zero")
    func balancesSumToZero() {
        let expenses = [
            SharedExpense(id: UUID(), amount: 90, paidBy: me,
                          shares: FamilySplit.equalShares(of: 90, among: [me, maria, sam])),
            SharedExpense(id: UUID(), amount: Decimal(string: "10")!, paidBy: maria,
                          shares: FamilySplit.equalShares(of: 10, among: [me, maria, sam])),
            SharedExpense(id: UUID(), amount: Decimal(string: "47.35")!, paidBy: sam,
                          shares: FamilySplit.equalShares(of: Decimal(string: "47.35")!, among: [me, sam]))
        ]

        let net = FamilySplit.balances(expenses: expenses)
        #expect(net.values.reduce(Decimal(0), +) == 0)
    }

    @Test("An expense one person both paid for and owns leaves nobody owing")
    func soloExpense() {
        let expense = SharedExpense(
            id: UUID(), amount: 40, paidBy: me,
            shares: FamilySplit.equalShares(of: 40, among: [me])
        )
        let net = FamilySplit.balances(expenses: [expense])
        #expect(net[me] == 0)
    }

    @Test("A settlement cancels the debt it paid off")
    func settlementClearsBalance() {
        let expense = SharedExpense(
            id: UUID(), amount: 90, paidBy: me,
            shares: FamilySplit.equalShares(of: 90, among: [me, maria, sam])
        )
        let paid = [Settlement(from: maria, to: me, amount: 30)]

        let net = FamilySplit.balances(expenses: [expense], settlements: paid)
        #expect(net[maria] == 0)
        #expect(net[me] == 30)
        #expect(net[sam] == -30)
    }

    // MARK: - Settling up

    @Test("Settling up clears every balance")
    func settleUpClearsEveryone() {
        let expenses = [
            SharedExpense(id: UUID(), amount: 90, paidBy: me,
                          shares: FamilySplit.equalShares(of: 90, among: [me, maria, sam])),
            SharedExpense(id: UUID(), amount: Decimal(string: "45.50")!, paidBy: maria,
                          shares: FamilySplit.equalShares(of: Decimal(string: "45.50")!, among: [me, maria, sam]))
        ]
        let net = FamilySplit.balances(expenses: expenses)
        let transfers = FamilySplit.settleUp(net)

        let after = FamilySplit.balances(expenses: expenses, settlements: transfers)
        #expect(after.values.allSatisfy { abs($0) <= Decimal(string: "0.01")! })
    }

    @Test("Nobody is asked to pay themselves, or to move nothing")
    func transfersAreSensible() {
        let expenses = [
            SharedExpense(id: UUID(), amount: 60, paidBy: me,
                          shares: FamilySplit.equalShares(of: 60, among: [me, maria]))
        ]
        let transfers = FamilySplit.settleUp(FamilySplit.balances(expenses: expenses))

        #expect(transfers.allSatisfy { $0.from != $0.to })
        #expect(transfers.allSatisfy { $0.amount > 0 })
        #expect(transfers.count == 1)
        #expect(transfers.first?.from == maria)
        #expect(transfers.first?.to == me)
        #expect(transfers.first?.amount == 30)
    }

    @Test("A settled family needs no transfers")
    func alreadySettled() {
        #expect(FamilySplit.settleUp([me: 0, maria: 0]).isEmpty)
        #expect(FamilySplit.settleUp([:]).isEmpty)
    }

    @Test("A stray cent is not worth a bank transfer")
    func ignoresSubCentImbalance() {
        // Balances can end a cent apart after rounding. Asking someone to
        // transfer €0.004 is noise, not bookkeeping.
        let transfers = FamilySplit.settleUp([
            me: Decimal(string: "0.004")!,
            maria: Decimal(string: "-0.004")!
        ])
        #expect(transfers.isEmpty)
    }

    @Test("Each person needs at most one transfer")
    func atMostOneTransferEach() {
        let fourth = UUID()
        let expenses = [
            SharedExpense(id: UUID(), amount: 100, paidBy: me,
                          shares: FamilySplit.equalShares(of: 100, among: [me, maria, sam, fourth])),
            SharedExpense(id: UUID(), amount: 60, paidBy: sam,
                          shares: FamilySplit.equalShares(of: 60, among: [me, maria, sam, fourth]))
        ]
        let transfers = FamilySplit.settleUp(FamilySplit.balances(expenses: expenses))

        for person in [me, maria, sam, fourth] {
            let involved = transfers.filter { $0.from == person || $0.to == person }
            #expect(involved.count <= 2, "\(person) appears in \(involved.count) transfers")
        }
    }
}
