import Foundation
import Testing
import SwiftData
@testable import Veralify

/// Deleting a debt has to take everything keyed to its id with it.
///
/// `DebtPayment` references a debt by a plain `Int`, not a SwiftData
/// relationship, so nothing cascades — and a new debt takes `max(remoteID) + 1`,
/// which hands a deleted debt's id straight to the next one created. Without a
/// purge, a brand-new card inherits a stranger's payment history.
@Suite("Deleting a debt")
struct DebtDeletionTests {

    /// An in-memory store, so the test never touches the app's real data.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DebtRecord.self, DebtPayment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func paid(_ debtID: Int, _ amount: Decimal) -> DebtPayment {
        DebtPayment(debtRemoteID: debtID, amount: amount, date: .now, isPaid: true)
    }

    @Test("Its payments go with it")
    func purgesPayments() throws {
        let context = try makeContext()
        context.insert(paid(3, 100))
        context.insert(paid(3, 150))
        context.insert(paid(1, 99))

        purgeRecords(forDebt: 3, in: context)

        let left = try context.fetch(FetchDescriptor<DebtPayment>())
        #expect(left.count == 1)
        #expect(left.first?.debtRemoteID == 1, "it took another debt's payment with it")
    }

    /// The bug this exists to stop: ids are reused, so leftovers are inherited.
    @Test("A reused id does not inherit the deleted debt's history")
    func reusedIDStartsClean() throws {
        let context = try makeContext()
        let old = DebtRecord(remoteID: 3, name: "Old card", balance: 500, apr: 10, minimumPayment: 50)
        context.insert(old)
        context.insert(paid(3, 400))

        purgeRecords(forDebt: old.remoteID, in: context)
        context.delete(old)

        // The next debt created takes max(remoteID) + 1, which is 3 again.
        context.insert(DebtRecord(remoteID: 3, name: "New card", balance: 800, apr: 12, minimumPayment: 80))

        let inherited = try context.fetch(FetchDescriptor<DebtPayment>())
            .filter { $0.debtRemoteID == 3 }
        #expect(inherited.isEmpty, "the new debt opened already part-paid")
    }

    @Test("Other debts are untouched")
    func leavesOthersAlone() throws {
        let context = try makeContext()
        context.insert(paid(1, 10))
        context.insert(paid(2, 20))

        purgeRecords(forDebt: 99, in: context)

        #expect(try context.fetch(FetchDescriptor<DebtPayment>()).count == 2)
    }

    /// The board remembers where each bubble was dragged, keyed by the same id.
    @Test("Its saved bubble position goes with it")
    func purgesBoardPosition() throws {
        let key = "boardPositions"
        let previous = UserDefaults.standard.string(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }

        UserDefaults.standard.set(#"{"3":[0.5,0.5],"1":[0.2,0.8]}"#, forKey: key)
        purgeRecords(forDebt: 3, in: try makeContext())

        let saved = UserDefaults.standard.string(forKey: key) ?? ""
        #expect(!saved.contains("\"3\""))
        #expect(saved.contains("\"1\""), "it cleared another bubble's position")
    }
}
