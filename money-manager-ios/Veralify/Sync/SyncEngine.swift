import Foundation
import Observation
import SwiftData
import os
import VeralifyCore

/// Two-way sync between the SwiftData store and the account's `money_*`
/// tables (contracts §2).
///
/// Each run pushes every local change, then pulls every table past its
/// cursor. It is safe to run at any time and any number of times: pushes are
/// upserts on the row id, pulls resume from the last cursor, and a run that
/// stops half-way — no signal, app suspended — leaves the store and the ledger
/// consistent, because both are committed together after each table.
///
/// Runs on the main actor against the main context, deliberately. Records are
/// not `Sendable`, the data is a household's worth of rows, and applying pulled
/// rows where the UI reads them means a screen updates the moment they land.
/// Only the network calls leave the main actor.
@MainActor
@Observable
final class SyncEngine {
    enum Status: Equatable {
        case idle
        case syncing
        /// The last run could not reach the server. Nothing is lost.
        case offline
        /// The last run finished, but some rows were refused or it failed.
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSyncedAt: Date?

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var remote: (any SyncRemote)?
    @ObservationIgnored private var userID: UUID?
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    /// True while the engine itself is saving, so its own saves do not look
    /// like user edits and schedule another run.
    @ObservationIgnored private var isApplying = false
    /// Set while signing out or deleting the account, so no run starts while
    /// the local copy is being removed.
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var saveObserver: NSObjectProtocol?
    @ObservationIgnored private let logger = Logger(subsystem: "com.veralify.moneymanager", category: "sync")

    private static let lastSyncedKey = "sync.lastSyncedAt"

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        lastSyncedAt = UserDefaults.standard.object(forKey: Self.lastSyncedKey) as? Date
    }

    // MARK: - Connection

    /// Points the engine at the signed-in account, or disconnects it.
    func connect(remote: (any SyncRemote)?, userID: UUID?) {
        self.remote = remote
        self.userID = userID
        isSuspended = false
        if remote == nil || userID == nil {
            debounce?.cancel()
            running?.cancel()
            status = .idle
        }
    }

    /// Stops syncing and waits for a run in progress to wind down. A run
    /// checks for cancellation between tables and its requests are cancelled
    /// with it, so this returns quickly.
    func suspend() async {
        isSuspended = true
        debounce?.cancel()
        running?.cancel()
        if let running { await running.value }
    }

    /// Undoes `suspend()` when the sign-out or deletion did not go ahead.
    func resume() {
        isSuspended = false
    }

    /// Makes the local store belong to `userID` before anything syncs.
    ///
    /// Data written before accounts existed is claimed by the first account
    /// to sign in, and uploaded. Data that belongs to a *different* account —
    /// possible only if a session ended without a sign-out, say by a revoked
    /// token — is removed first: its ledger would otherwise read the new
    /// account's rows as deletions, and its records would be uploaded into the
    /// wrong account.
    func adopt(userID: UUID) throws {
        let owner = userID.uuidString.lowercased()
        let state = try SyncStateRecord.load(in: context)
        var ledger = state.ledger
        guard ledger.userID != owner else { return }

        if ledger.userID != nil {
            logger.notice("Store belonged to another account; clearing synced data before adopting it")
            try LocalData.removeSyncedData(in: context)
            context.insert(SyncStateRecord(ledger: SyncLedger(userID: owner)))
        } else {
            ledger.userID = owner
            state.ledger = ledger
        }
        try save()
    }

    // MARK: - Triggers

    /// Syncs a couple of seconds after the app saves, so a burst of edits —
    /// typing a form, dragging on the board — becomes one run.
    func observeLocalSaves() {
        guard saveObserver == nil else { return }
        // `queue: nil` delivers the notification synchronously on the thread
        // that saved. That is what lets `isApplying` filter out the engine's
        // own saves: delivered later on a queue, the flag would already be
        // reset and every sync would schedule the next one.
        // VERIFY: SwiftData posts ModelContext.didSave for the main context's
        // saves (explicit and autosave) on the main thread.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: nil
        ) { [weak self] _ in
            // Only the main context holds the user's edits.
            guard Thread.isMainThread else { return }
            MainActor.assumeIsolated { self?.localStoreDidSave() }
        }
    }

    private func localStoreDidSave() {
        guard !isApplying, !isSuspended, remote != nil else { return }
        scheduleSync()
    }

    /// Syncs after `delay`, replacing any run already scheduled.
    func scheduleSync(after delay: Duration = .seconds(2)) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Syncs now. If a run is already going, one more follows it, so a change
    /// made during a run is never left waiting for the next trigger.
    func sync() async {
        guard !isSuspended else { return }
        if let running {
            rerunRequested = true
            await running.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.rerunRequested = false
                await self.runOnce()
            } while self.rerunRequested && self.remote != nil && !self.isSuspended && !Task.isCancelled
        }
        running = task
        await task.value
        running = nil
    }

    // MARK: - Local state

    /// Rows changed or deleted here that the server does not have yet. Used
    /// to warn before signing out, which removes them from the phone.
    func pendingChangeCount() -> Int {
        guard let userID, let state = try? SyncStateRecord.load(in: context) else { return 0 }
        let run = SyncRun(
            context: context, remote: nil, userID: userID, calendar: .current,
            state: state, logger: logger, save: { [weak self] in try self?.save() }
        )
        return (try? run.pendingChangeCount()) ?? 0
    }

    /// Clears the synced data and the ledger, for signing out: the account
    /// keeps everything, and the next account to sign in starts clean.
    func removeLocalCopy() throws {
        debounce?.cancel()
        try LocalData.removeSyncedData(in: context)
        try save()
        lastSyncedAt = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncedKey)
        status = .idle
    }

    // MARK: - Running

    private func save() throws {
        guard context.hasChanges else { return }
        isApplying = true
        defer { isApplying = false }
        try context.save()
    }

    private func runOnce() async {
        guard let remote, let userID else { return }
        // Rows migrated from before sync share one id until the launch-time
        // repair has run; pushing them would overwrite each other.
        SyncMigration.runIfNeeded(in: context)
        guard SyncMigration.isComplete else {
            status = .failed(String(localized: "Sync failed. It will be retried."))
            return
        }
        status = .syncing
        do {
            try adopt(userID: userID)
            let state = try SyncStateRecord.load(in: context)
            let run = SyncRun(
                context: context, remote: remote, userID: userID, calendar: .current,
                state: state, logger: logger, save: { [weak self] in try self?.save() }
            )
            try await run.run()
            lastSyncedAt = .now
            UserDefaults.standard.set(lastSyncedAt, forKey: Self.lastSyncedKey)
            status = run.rowFailures == 0
                ? .idle
                : .failed(String(localized: "Some changes could not be synced. They will be retried."))
        } catch is CancellationError {
            try? save()
            status = .idle
        } catch let failure as SyncFailure {
            try? save()
            if Task.isCancelled {
                status = .idle
                return
            }
            switch failure {
            case .offline:
                status = .offline
            case .signedOut:
                status = .failed(String(localized: "Sign in again to sync."))
            case .server(let message):
                logger.error("Sync failed: \(message, privacy: .public)")
                status = .failed(String(localized: "Sync failed. It will be retried."))
            }
        } catch {
            try? save()
            logger.error("Sync failed: \(String(describing: error), privacy: .public)")
            status = .failed(String(localized: "Sync failed. It will be retried."))
        }
    }
}

// MARK: - One run

/// The state of a single sync run: the ledger being updated and the local
/// lookups built along the way.
@MainActor
private final class SyncRun {
    struct LocalRow {
        let id: String
        /// Nil while the row cannot be pushed yet — a payment whose debt is
        /// unknown, a logged month whose income is gone.
        let row: SyncRow?
        let model: any SyncedModel
    }

    typealias Pulled = (meta: SyncMeta, row: SyncRow)

    let context: ModelContext
    let remote: (any SyncRemote)?
    let userID: UUID
    let calendar: Calendar
    let state: SyncStateRecord
    let logger: Logger
    let saveContext: @MainActor () throws -> Void
    var ledger: SyncLedger
    private var committed: SyncLedger
    private(set) var rowFailures = 0

    /// Debts as they stand during the run, including ones inserted by it
    /// before the next save.
    private var debtCache: [DebtRecord]?

    init(
        context: ModelContext, remote: (any SyncRemote)?, userID: UUID, calendar: Calendar,
        state: SyncStateRecord, logger: Logger, save: @escaping @MainActor () throws -> Void
    ) {
        self.context = context
        self.remote = remote
        self.userID = userID
        self.calendar = calendar
        self.state = state
        self.logger = logger
        self.saveContext = save
        ledger = state.ledger
        committed = ledger
    }

    private func requireRemote() throws -> any SyncRemote {
        guard let remote else { throw SyncFailure.signedOut }
        return remote
    }

    /// Saves the store and the ledger together.
    private func commit() throws {
        if ledger != committed {
            state.ledger = ledger
            committed = ledger
        }
        try saveContext()
    }

    private func all<M: PersistentModel>(_ type: M.Type) throws -> [M] {
        try context.fetch(FetchDescriptor<M>())
    }

    private func fingerprint(_ row: SyncRow) -> String {
        SyncJSON.fingerprint(of: row)
    }

    private func noteRowFailure(_ table: SyncTable, _ error: Error) {
        rowFailures += 1
        logger.error("\(table.rawValue, privacy: .public): row skipped — \(String(describing: error), privacy: .public)")
    }

    func run() async throws {
        for table in SyncTable.allCases {
            try Task.checkCancellation()
            try await push(table)
        }
        for table in SyncTable.allCases {
            try Task.checkCancellation()
            try await pull(table)
        }
        if try seedCategories() { try await push(.categories) }
        try commit()
    }

    // MARK: Local rows

    private func debtIDsByNumber() throws -> [Int: UUID] {
        Dictionary(try all(DebtRecord.self).map { ($0.remoteID, $0.id) }, uniquingKeysWith: { first, _ in first })
    }

    private func localRows(_ table: SyncTable) throws -> [LocalRow] {
        func rows<M: SyncedModel>(_ type: M.Type, _ encode: (M) -> SyncRow?) throws -> [LocalRow] {
            try all(type).map { LocalRow(id: $0.syncID, row: encode($0), model: $0) }
        }
        let user = userID
        let calendar = calendar
        switch table {
        case .settings, .receipts:
            return []
        case .categories:
            return try rows(MoneyCategory.self) { CategoryRow($0).encoded(userID: user) }
        case .merchantRules:
            return try rows(MerchantRule.self) { MerchantRuleRow($0).encoded(userID: user) }
        case .income:
            return try rows(IncomeSource.self) { IncomeRow($0).encoded(userID: user) }
        case .incomeActuals:
            return try rows(IncomeActual.self) { $0.syncRow?.encoded(userID: user, calendar: calendar) }
        case .expenses:
            return try rows(ExpenseItem.self) { ExpenseRow($0).encoded(userID: user) }
        case .debts:
            return try rows(DebtRecord.self) { DebtRow($0).encoded(userID: user) }
        case .debtPayments:
            let debtIDs = try debtIDsByNumber()
            return try rows(DebtPayment.self) { $0.syncRow(debtIDs: debtIDs)?.encoded(userID: user, calendar: calendar) }
        case .transactions:
            return try rows(TransactionRecord.self) { TransactionRow($0).encoded(userID: user, calendar: calendar) }
        case .losses:
            return try rows(MoneyLoss.self) { LossRow($0).encoded(userID: user, calendar: calendar) }
        case .snapshots:
            return try rows(MonthlySnapshot.self) { SnapshotRow($0).encoded(userID: user, calendar: calendar) }
        case .budgets:
            return try rows(CategoryBudget.self) { BudgetRow($0).encoded(userID: user) }
        }
    }

    private func isDirty(_ local: LocalRow, table: SyncTable) -> Bool {
        guard let row = local.row else { return false }
        return local.model.needsPush
            || ledger.isDirty(table: table.rawValue, id: local.id, fingerprint: fingerprint(row))
    }

    func pendingChangeCount() throws -> Int {
        var count = 0
        for table in SyncTable.allCases where table != .settings && !table.isPullOnly {
            let locals = try localRows(table)
            let live = locals.filter { $0.model.deletedAt == nil }
            count += live.filter { isDirty($0, table: table) }.count
            count += ledger.deletedLocally(table: table.rawValue, localIDs: Set(live.map(\.id))).count
        }
        if let plan = try all(PlanSettings.self).first {
            let rows = SettingsRows(plan).encoded(userID: userID, calendar: calendar)
            count += rows.filter {
                plan.needsPush || ledger.isDirty(table: SyncTable.settings.rawValue, id: $0.key, fingerprint: fingerprint($0.value))
            }.count
        }
        return count
    }

    // MARK: Push

    private func push(_ table: SyncTable) async throws {
        // Receipt rows are written by receipt capture's own queue.
        if table.isPullOnly { return }
        if table == .settings {
            try await pushSettings()
            return
        }
        let remote = try requireRemote()
        let key = table.rawValue
        let locals = try localRows(table)

        // Deletions first: rows the server has that are gone from here, plus
        // rows soft-deleted here, which are removed once the server has the
        // delete. First, because a table unique on a natural key (a budget's
        // category, a snapshot's month) refuses a replacement row while the
        // row it replaces is still live on the server.
        let live = Set(locals.filter { $0.model.deletedAt == nil }.map(\.id))
        var softDeleted: [String: any SyncedModel] = [:]
        for local in locals where local.model.deletedAt != nil {
            if ledger.isKnown(table: key, id: local.id) {
                softDeleted[local.id] = local.model
            } else {
                // Never reached the server, so there is nothing to tell it.
                context.delete(local.model)
            }
        }
        let gone = ledger.deletedLocally(table: key, localIDs: live)
        var index = 0
        while index < gone.count {
            let batch = Array(gone[index..<min(index + 100, gone.count)])
            index += 100
            do {
                try await remote.softDelete(table, ids: batch, userID: userID, at: .now)
                for id in batch {
                    ledger.forget(table: key, id: id)
                    if let model = softDeleted[id] { context.delete(model) }
                }
            } catch let failure as SyncFailure where failure.isRowSpecific {
                noteRowFailure(table, failure)
            }
        }

        var pending: [(local: LocalRow, row: SyncRow, fingerprint: String)] = []
        for local in locals where local.model.deletedAt == nil && isDirty(local, table: table) {
            guard let row = local.row else { continue }
            pending.append((local, row, fingerprint(row)))
        }

        func markPushed(_ items: ArraySlice<(local: LocalRow, row: SyncRow, fingerprint: String)>) {
            for item in items {
                ledger.record(table: key, id: item.local.id, fingerprint: item.fingerprint)
                item.local.model.needsPush = false
                item.local.model.updatedAt = .now
            }
        }

        var start = 0
        while start < pending.count {
            let batch = pending[start..<min(start + 200, pending.count)]
            start += 200
            do {
                try await remote.upsert(table, rows: batch.map(\.row))
                markPushed(batch)
            } catch let failure as SyncFailure where failure.isRowSpecific {
                // One refused row (a check constraint, a unique clash with a
                // row another phone created) fails the whole statement. Retry
                // one by one so the rest still go up; the refused one stays
                // dirty and is tried again next run.
                for index in batch.indices {
                    do {
                        try await remote.upsert(table, rows: [pending[index].row])
                        markPushed(pending[index...index])
                    } catch let failure as SyncFailure where failure.isRowSpecific {
                        noteRowFailure(table, failure)
                    }
                }
            }
        }
        try commit()
    }

    private func pushSettings() async throws {
        guard let plan = try all(PlanSettings.self).first else { return }
        let remote = try requireRemote()
        let key = SyncTable.settings.rawValue
        let rows = SettingsRows(plan).encoded(userID: userID, calendar: calendar)
        let pending = rows
            .filter { plan.needsPush || ledger.isDirty(table: key, id: $0.key, fingerprint: fingerprint($0.value)) }
            .sorted { $0.key < $1.key }
        guard !pending.isEmpty else { return }
        do {
            try await remote.upsert(.settings, rows: pending.map(\.value))
            for (setting, row) in pending { ledger.record(table: key, id: setting, fingerprint: fingerprint(row)) }
            plan.needsPush = false
            plan.updatedAt = .now
        } catch let failure as SyncFailure where failure.isRowSpecific {
            noteRowFailure(.settings, failure)
        }
        try commit()
    }

    // MARK: Pull

    private func pull(_ table: SyncTable) async throws {
        let remote = try requireRemote()
        let key = table.rawValue
        while true {
            try Task.checkCancellation()
            let cursor = ledger.cursor(for: key)
            let rows = try await remote.pull(table, after: cursor, userID: userID)
            var page: [Pulled] = []
            var highest = cursor
            for row in rows {
                if let seq = row["sync_seq"]?.intValue { highest = max(highest, seq) }
                do {
                    page.append((try SyncMeta(row: row, table: table), row))
                } catch {
                    noteRowFailure(table, error)
                }
            }
            try apply(table, page)
            // The cursor passes rows that failed to apply as well. Holding it
            // back would stall the table for good on one bad row; the row is
            // logged, and pulled again whenever it next changes.
            ledger.advanceCursor(for: key, to: highest)
            try commit()
            if SyncMerge.isLastPage(rowCount: rows.count, pageSize: SyncTable.pageSize) || highest == cursor { break }
        }
    }

    private func apply(_ table: SyncTable, _ page: [Pulled]) throws {
        guard !page.isEmpty else { return }
        let user = userID
        let calendar = calendar
        switch table {
        case .settings:
            try applySettings(page)

        case .receipts:
            try applyReceipts(page)

        case .categories:
            try merge(
                table, page, locals: all(MoneyCategory.self),
                localKey: { $0.key }, remoteKey: { $0["key"]?.stringValue },
                encode: { CategoryRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try CategoryRow(row: row)
                    return MoneyCategory(
                        key: r.key, name: r.name, icon: r.icon, color: r.color, kind: r.kind,
                        sortOrder: r.sortOrder, archived: r.archived, createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try CategoryRow(row: row)); return true }
            )

        case .merchantRules:
            try merge(
                table, page, locals: all(MerchantRule.self),
                localKey: { $0.merchantKey }, remoteKey: { $0["merchant_key"]?.stringValue },
                encode: { MerchantRuleRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try MerchantRuleRow(row: row)
                    return MerchantRule(
                        merchantKey: r.merchantKey, categoryKey: r.categoryKey, scope: r.scope, hits: r.hits,
                        createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try MerchantRuleRow(row: row)); return true }
            )

        case .income:
            try merge(
                table, page, locals: all(IncomeSource.self),
                encode: { IncomeRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try IncomeRow(row: row)
                    return IncomeSource(
                        name: r.name, amount: r.amount, kind: r.kind, payday: r.payday, isActive: r.isActive,
                        createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try IncomeRow(row: row)); return true }
            )

        case .incomeActuals:
            let incomes = Dictionary(try all(IncomeSource.self).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            try merge(
                table, page, locals: all(IncomeActual.self),
                encode: { $0.syncRow?.encoded(userID: user, calendar: calendar) },
                insert: { row, meta in
                    let r = try IncomeActualRow(row: row, calendar: calendar)
                    // Its income was deleted here or never existed: the row
                    // has nothing to belong to.
                    guard let income = incomes[r.incomeID] else { return nil }
                    return IncomeActual(month: r.month, amount: r.amount, source: income, createdAt: meta.createdAt ?? .now, id: r.id)
                },
                update: { model, row in
                    let r = try IncomeActualRow(row: row, calendar: calendar)
                    guard let income = incomes[r.incomeID] else { return false }
                    model.apply(r, source: income, calendar: calendar)
                    return true
                }
            )

        case .expenses:
            try merge(
                table, page, locals: all(ExpenseItem.self),
                encode: { ExpenseRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try ExpenseRow(row: row)
                    return ExpenseItem(
                        name: r.name, amount: r.amount, category: r.category, dueDay: r.dueDay, isActive: r.isActive,
                        createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try ExpenseRow(row: row)); return true }
            )

        case .debts:
            debtCache = try all(DebtRecord.self)
            try merge(
                table, page, locals: debtCache ?? [],
                encode: { DebtRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try DebtRow(row: row)
                    let number = try claimDebtNumber(r.localID, for: r.id)
                    let debt = DebtRecord(
                        remoteID: number, name: r.name, balance: r.balance, apr: r.apr,
                        minimumPayment: r.minimumPayment, extraPayment: r.extraPayment, dueDay: r.dueDay,
                        priority: r.priority, createdAt: meta.createdAt ?? .now, id: r.id
                    )
                    debtCache?.append(debt)
                    return debt
                },
                update: { debt, row in
                    let r = try DebtRow(row: row)
                    if let number = r.localID, number != debt.remoteID {
                        // Renumbered on another phone. Payments follow the debt.
                        let previous = debt.remoteID
                        _ = try claimDebtNumber(number, for: debt.id)
                        try movePayments(from: previous, to: number)
                        debt.remoteID = number
                    }
                    debt.apply(r)
                    return true
                },
                afterApply: { debt, row in
                    // Created on the web, which has no debt numbers: the number
                    // this phone gave it has to go back up.
                    if row["local_id"]?.isNull ?? true { debt.needsPush = true }
                },
                willDelete: { [context] debt in purgeRecords(forDebt: debt.remoteID, in: context) }
            )
            debtCache = nil

        case .debtPayments:
            let debts = Dictionary(try all(DebtRecord.self).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let debtIDs = try debtIDsByNumber()
            try merge(
                table, page, locals: all(DebtPayment.self),
                encode: { $0.syncRow(debtIDs: debtIDs)?.encoded(userID: user, calendar: calendar) },
                insert: { row, meta in
                    let r = try DebtPaymentRow(row: row, calendar: calendar)
                    guard let debt = debts[r.debtID] else { return nil }
                    let payment = DebtPayment(
                        debtRemoteID: debt.remoteID, amount: r.amount, interestPortion: r.interestPortion,
                        date: r.date, isPaid: r.isPaid, isEarlyPayoff: r.isEarlyPayoff,
                        previousMinimum: r.previousMinimum, newMinimum: r.newMinimum, note: r.note,
                        createdAt: meta.createdAt ?? .now, id: r.id
                    )
                    payment.appliedAmount = r.appliedAmount
                    return payment
                },
                update: { payment, row in
                    let r = try DebtPaymentRow(row: row, calendar: calendar)
                    guard let debt = debts[r.debtID] else { return false }
                    payment.apply(r, debtNumber: debt.remoteID, calendar: calendar)
                    return true
                }
            )

        case .transactions:
            try merge(
                table, page, locals: all(TransactionRecord.self),
                encode: { TransactionRow($0).encoded(userID: user, calendar: calendar) },
                insert: { row, meta in
                    let r = try TransactionRow(row: row, calendar: calendar)
                    return TransactionRecord(
                        occurredAt: r.occurredAt, name: r.merchant, amount: r.amount,
                        direction: r.isCredit ? .credit : .debit,
                        scope: EntryScope(rawValue: r.scope) ?? .personal,
                        category: r.categoryKey,
                        account: r.account, notes: r.notes, createdAt: meta.createdAt ?? .now,
                        currency: r.currency, taxAmount: r.taxAmount, receiptID: r.receiptID,
                        source: EntrySource(rawValue: r.source) ?? .manual, id: r.id
                    )
                },
                update: { model, row in model.apply(try TransactionRow(row: row, calendar: calendar)); return true }
            )

        case .losses:
            try merge(
                table, page, locals: all(MoneyLoss.self),
                encode: { LossRow($0).encoded(userID: user, calendar: calendar) },
                insert: { row, meta in
                    let r = try LossRow(row: row, calendar: calendar)
                    return MoneyLoss(
                        date: r.date, amount: r.amount, reason: LossReason(rawValue: r.reason) ?? .other,
                        note: r.note, createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try LossRow(row: row, calendar: calendar), calendar: calendar); return true }
            )

        case .snapshots:
            try merge(
                table, page, locals: all(MonthlySnapshot.self),
                localKey: { SyncFormat.monthDate($0.month, calendar: calendar) },
                remoteKey: { $0["month"]?.stringValue.map { String($0.prefix(10)) } },
                encode: { SnapshotRow($0).encoded(userID: user, calendar: calendar) },
                insert: { row, meta in
                    let r = try SnapshotRow(row: row, calendar: calendar)
                    return MonthlySnapshot(
                        month: r.month, income: r.income, expenses: r.expenses, debtMinimums: r.debtMinimums,
                        debtBalance: r.debtBalance, recordedAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try SnapshotRow(row: row, calendar: calendar), calendar: calendar); return true }
            )

        case .budgets:
            try merge(
                table, page, locals: all(CategoryBudget.self),
                localKey: { CategoryKeys.key(forLocal: $0.category) }, remoteKey: { $0["category_key"]?.stringValue },
                encode: { BudgetRow($0).encoded(userID: user) },
                insert: { row, meta in
                    let r = try BudgetRow(row: row)
                    return CategoryBudget(
                        category: r.categoryKey, limit: r.monthlyLimit,
                        createdAt: meta.createdAt ?? .now, id: r.id
                    )
                },
                update: { model, row in model.apply(try BudgetRow(row: row)); return true }
            )
        }
    }

    /// Applies one page of pulled rows to one model type.
    ///
    /// - `localKey`/`remoteKey`: a natural key the table is unique on (a
    ///   snapshot's month, a budget's category). A row created on two phones
    ///   before either synced has two ids but one key; the local copy takes
    ///   the server's id and values rather than failing the unique index on
    ///   every push from then on.
    /// - `insert` returns nil and `update` false when a row cannot be applied
    ///   yet because the record it belongs to is missing here.
    private func merge<M: SyncedModel>(
        _ table: SyncTable,
        _ page: [Pulled],
        locals: [M],
        localKey: ((M) -> String?)? = nil,
        remoteKey: ((SyncRow) -> String?)? = nil,
        encode: (M) -> SyncRow?,
        insert: (SyncRow, SyncMeta) throws -> M?,
        update: (M, SyncRow) throws -> Bool,
        afterApply: ((M, SyncRow) -> Void)? = nil,
        willDelete: ((M) -> Void)? = nil
    ) throws {
        let key = table.rawValue
        var byID = Dictionary(locals.map { ($0.syncID, $0) }, uniquingKeysWith: { first, _ in first })
        var unsyncedByKey: [String: M] = [:]
        if let localKey {
            for model in locals where model.deletedAt == nil && !ledger.isKnown(table: key, id: model.syncID) {
                if let natural = localKey(model) { unsyncedByKey[natural] = model }
            }
        }

        func record(_ model: M) {
            if let row = encode(model) {
                ledger.record(table: key, id: model.syncID, fingerprint: fingerprint(row))
            }
        }

        for (meta, row) in page {
            do {
                var local = byID[meta.id]
                var adopted = false
                if local == nil, !meta.isDeleted,
                   let natural = remoteKey?(row), let twin = unsyncedByKey[natural],
                   let remoteID = UUID(uuidString: meta.id) {
                    unsyncedByKey[natural] = nil
                    byID[twin.syncID] = nil
                    twin.id = remoteID
                    byID[meta.id] = twin
                    local = twin
                    adopted = true
                }

                var dirty = false
                if let local, !adopted {
                    if local.needsPush || local.deletedAt != nil {
                        dirty = true
                    } else if let encoded = encode(local) {
                        dirty = ledger.isDirty(table: key, id: meta.id, fingerprint: fingerprint(encoded))
                    } else {
                        dirty = true
                    }
                }

                switch SyncMerge.decide(localExists: local != nil, localDirty: dirty, remoteDeleted: meta.isDeleted) {
                case .insert:
                    guard let model = try insert(row, meta) else { continue }
                    context.insert(model)
                    model.needsPush = false
                    model.updatedAt = meta.updatedAt ?? .now
                    afterApply?(model, row)
                    byID[meta.id] = model
                    record(model)
                case .update:
                    guard let local, try update(local, row) else { continue }
                    local.needsPush = false
                    local.updatedAt = meta.updatedAt ?? .now
                    afterApply?(local, row)
                    record(local)
                case .keepLocal:
                    continue
                case .deleteLocal:
                    guard let local else { continue }
                    willDelete?(local)
                    context.delete(local)
                    byID[meta.id] = nil
                    ledger.forget(table: key, id: meta.id)
                case .skip:
                    ledger.forget(table: key, id: meta.id)
                }
            } catch {
                noteRowFailure(table, error)
            }
        }
    }

    // MARK: Debt numbers

    private func cachedDebts() throws -> [DebtRecord] {
        if let debtCache { return debtCache }
        let debts = try all(DebtRecord.self)
        debtCache = debts
        return debts
    }

    /// Returns `wanted` for the debt `debtID`, first renumbering any other
    /// debt here that holds it, together with its payments. With no number
    /// (a debt created on the web), the next free one.
    private func claimDebtNumber(_ wanted: Int?, for debtID: UUID) throws -> Int {
        let debts = try cachedDebts()
        guard let wanted else { return DebtNumbering.nextFree(after: debts.map(\.remoteID)) }
        for other in debts where other.remoteID == wanted && other.id != debtID {
            let fresh = DebtNumbering.nextFree(after: debts.map(\.remoteID) + [wanted])
            try movePayments(from: wanted, to: fresh)
            other.remoteID = fresh
            other.needsPush = true
            logger.notice("Debt number \(wanted) was taken on another device; renumbered the local debt to \(fresh)")
        }
        return wanted
    }

    private func movePayments(from old: Int, to new: Int) throws {
        let payments = try context.fetch(
            FetchDescriptor<DebtPayment>(predicate: #Predicate { $0.debtRemoteID == old })
        )
        for payment in payments { payment.debtRemoteID = new }
    }

    // MARK: Settings

    private func applySettings(_ page: [Pulled]) throws {
        let key = SyncTable.settings.rawValue
        let existing = try all(PlanSettings.self).first
        var values = existing.map(SettingsRows.init) ?? SettingsRows(
            targetMonths: 16, startDate: .now,
            payoffStrategy: PayoffStrategy.highestInterest.rawValue, homeCurrency: AppSettings.currencyCode
        )
        let localRows = existing.map { SettingsRows($0).encoded(userID: userID, calendar: calendar) } ?? [:]

        var applied: [String] = []
        for (meta, row) in page where !meta.isDeleted {
            guard let value = row["value"]?.stringValue else { continue }
            if let existing, let current = localRows[meta.id],
               existing.needsPush || ledger.isDirty(table: key, id: meta.id, fingerprint: fingerprint(current)) {
                continue  // edited here since the last push: the local value goes up next
            }
            if values.apply(key: meta.id, value: value, calendar: calendar) { applied.append(meta.id) }
        }
        guard !applied.isEmpty else { return }

        let plan: PlanSettings
        if let existing {
            plan = existing
        } else {
            plan = PlanSettings()
            context.insert(plan)
            // Keys the server did not have are recorded nowhere, so they
            // still read as changed and go up on the next push.
            plan.needsPush = false
        }
        plan.apply(values, calendar: calendar)
        plan.updatedAt = .now
        let encoded = SettingsRows(plan).encoded(userID: userID, calendar: calendar)
        for setting in applied {
            if let row = encoded[setting] { ledger.record(table: key, id: setting, fingerprint: fingerprint(row)) }
        }
    }

    // MARK: Receipts

    /// Receipts captured on another device or e-mailed in, and the server's
    /// progress on the ones captured here (contracts §5).
    ///
    /// The server owns `status` and the reading; the phone owns the columns it
    /// may write (paths, source, the confirmed transaction), and a change to
    /// those still waiting in receipt capture's queue (`needsPush`) wins.
    private func applyReceipts(_ page: [Pulled]) throws {
        let locals = Dictionary(
            try all(ReceiptRecord.self).map { ($0.id.uuidString.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (meta, row) in page {
            do {
                let local = locals[meta.id]
                if meta.isDeleted {
                    // Deleted elsewhere. One with a change still waiting to go
                    // up is left for the queue to settle.
                    if let local, !local.needsPush {
                        ReceiptImageStore.delete(receiptID: local.id)
                        context.delete(local)
                    }
                    continue
                }

                let remote = try ReceiptRow(row: row)
                let record: ReceiptRecord
                if let local {
                    record = local
                } else {
                    record = ReceiptRecord(
                        id: remote.id, source: remote.source, localImageNames: [],
                        createdAt: meta.createdAt ?? .now
                    )
                    context.insert(record)
                    record.rowCreated = true
                    record.needsPush = false
                }

                // While this phone is still sending the receipt, its own
                // captured/uploading status drives the queue; the server's
                // "uploaded" would skip pages that are not up yet.
                let isSending = !record.localImageNames.isEmpty
                    && [ReceiptStatus.captured.rawValue, ReceiptStatus.uploading.rawValue].contains(record.statusRaw)
                // Confirmed here, but the transaction has not reached the
                // server yet, so the server still says "extracted" with no
                // link. The database links the two when the transaction
                // arrives; until then this phone's confirmation stands.
                let isLinkPending = record.transactionID != nil && remote.transactionID == nil
                if !isSending, !isLinkPending, record.statusRaw != remote.status { record.statusRaw = remote.status }
                if let json = remote.extractionJSON {
                    let data = Data(json.utf8)
                    if record.extractionData != data { record.extractionData = data }
                }
                if !record.needsPush, !isLinkPending {
                    if record.imagePaths != remote.imagePaths { record.imagePaths = remote.imagePaths }
                    if record.sourceRaw != remote.source { record.sourceRaw = remote.source }
                    if record.transactionID != remote.transactionID { record.transactionID = remote.transactionID }
                }
                record.updatedAt = meta.updatedAt ?? .now
            } catch {
                noteRowFailure(.receipts, error)
            }
        }
    }

    // MARK: Categories

    /// Makes sure the account has its categories (contracts §3).
    ///
    /// The server seeds the default list when an account is created; this
    /// covers accounts made before that, and only when the server has sent no
    /// categories at all — re-adding one the user deleted on the web would be
    /// wrong. It also adds a category for any free-text category the phone's
    /// entries use, so the key every such entry syncs with names something.
    /// Returns whether anything was added.
    private func seedCategories() throws -> Bool {
        let categories = try all(MoneyCategory.self)
        var keys = Set(categories.map(\.key))
        var added = false

        if !ledger.seededCategories {
            if ledger.cursor(for: SyncTable.categories.rawValue) == 0 {
                for category in CategoryKeys.defaults where !keys.contains(category.key) {
                    context.insert(MoneyCategory(
                        key: category.key, name: category.name, icon: category.icon, sortOrder: category.sortOrder
                    ))
                    keys.insert(category.key)
                    added = true
                }
            }
            ledger.seededCategories = true
        }

        var used: [String: String] = [:]
        for entry in try all(TransactionRecord.self) {
            let key = CategoryKeys.key(forLocal: entry.category)
            if used[key] == nil { used[key] = entry.category }
        }
        for budget in try all(CategoryBudget.self) {
            let key = CategoryKeys.key(forLocal: budget.category)
            if used[key] == nil { used[key] = budget.category }
        }
        var order = (categories.map(\.sortOrder).max() ?? CategoryKeys.defaults.count) + 1
        for (key, name) in used.sorted(by: { $0.key < $1.key })
        where !keys.contains(key) && !CategoryKeys.defaultKeys.contains(key) {
            context.insert(MoneyCategory(key: key, name: name, sortOrder: order))
            keys.insert(key)
            order += 1
            added = true
        }

        try commit()
        return added
    }
}
