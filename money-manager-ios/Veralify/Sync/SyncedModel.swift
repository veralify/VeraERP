import Foundation
import SwiftData
import VeralifyCore

/// A SwiftData record that mirrors a row of a `money_*` table (contracts §2).
///
/// - `id`: the row's UUID on the server as well as here. Generated on the
///   phone, so a record can be created offline.
/// - `updatedAt`: when the row last changed, as far as this phone knows — the
///   server's `updated_at` after a pull, the push time after a push.
/// - `deletedAt`: set to delete the row *softly*: it stays until the deletion
///   has reached the server and is then removed. A plain `context.delete` is
///   equally safe — the sync ledger notices the row is gone and soft-deletes
///   it on the server — so screens can keep deleting the way they always have.
/// - `needsPush`: forces the row into the next push. Edits made anywhere in the
///   app are found without it (see `SyncLedger`); it exists for writes that
///   must go up even when the row looks unchanged, such as a debt number the
///   server does not have yet.
protocol SyncedModel: PersistentModel {
    var id: UUID { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var needsPush: Bool { get set }
}

extension IncomeSource: SyncedModel {}
extension IncomeActual: SyncedModel {}
extension ExpenseItem: SyncedModel {}
extension DebtRecord: SyncedModel {}
extension DebtPayment: SyncedModel {}
extension PlanSettings: SyncedModel {}
extension TransactionRecord: SyncedModel {}
extension MoneyLoss: SyncedModel {}
extension MonthlySnapshot: SyncedModel {}
extension CategoryBudget: SyncedModel {}
extension MoneyCategory: SyncedModel {}
extension MerchantRule: SyncedModel {}

extension SyncedModel {
    /// The id as the server writes it, lower-case.
    var syncID: String { id.uuidString.lowercased() }
}

extension ModelContext {
    /// Deletes a synced record and makes sure the deletion reaches the server.
    ///
    /// Equivalent to `delete(_:)` for sync purposes (the ledger would catch a
    /// plain delete too); preferred in new code because it says what it means.
    func deleteSynced(_ model: some SyncedModel) {
        model.deletedAt = .now
        delete(model)
    }
}

/// Where the sync ledger lives: one row, beside the data it describes, so a
/// save commits a pulled row and the ledger entry for it together — a crash
/// between the two cannot make the phone forget it already has a row.
@Model
final class SyncStateRecord {
    var ledgerData: Data
    var updatedAt: Date

    init(ledger: SyncLedger = SyncLedger()) {
        ledgerData = (try? JSONEncoder().encode(ledger)) ?? Data()
        updatedAt = .now
    }

    var ledger: SyncLedger {
        get { (try? JSONDecoder().decode(SyncLedger.self, from: ledgerData)) ?? SyncLedger() }
        set {
            ledgerData = (try? JSONEncoder().encode(newValue)) ?? ledgerData
            updatedAt = .now
        }
    }

    @MainActor
    static func load(in context: ModelContext) throws -> SyncStateRecord {
        if let existing = try context.fetch(FetchDescriptor<SyncStateRecord>()).first {
            return existing
        }
        let record = SyncStateRecord()
        context.insert(record)
        return record
    }
}
