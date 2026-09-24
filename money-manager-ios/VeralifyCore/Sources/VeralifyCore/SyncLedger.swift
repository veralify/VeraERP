import Foundation

/// What this device knows about the server, per table.
///
/// Two things, both needed to sync without asking every screen in the app to
/// cooperate:
///
/// - **Cursors.** The highest `sync_seq` pulled per table (contracts §2). The
///   next pull asks only for rows past it.
/// - **Fingerprints.** For every row the server is known to hold, the
///   fingerprint of the row as it was last pushed or pulled. A local row whose
///   fingerprint differs has been edited here and needs pushing; a known id
///   with no local row any more was deleted here and needs a soft delete on
///   the server.
///
/// Detecting edits and deletes by comparison, rather than by every screen
/// setting a dirty flag, is deliberate: the app has dozens of places that edit
/// or delete a record, and one of them forgetting to flag a change would lose
/// it silently. A comparison cannot forget.
public struct SyncLedger: Codable, Sendable, Equatable {
    /// The account this ledger describes. A ledger is never reused across
    /// accounts: another account's fingerprints would read as deletions.
    public var userID: String?
    public var cursors: [String: Int64] = [:]
    /// Table → row id → fingerprint.
    public var known: [String: [String: String]] = [:]
    /// Whether the default categories were checked for this account.
    public var seededCategories = false

    public init(userID: String? = nil) {
        self.userID = userID
    }

    // MARK: Cursors

    public func cursor(for table: String) -> Int64 {
        cursors[table] ?? 0
    }

    /// Moves the cursor forward, never back. A page that arrives out of order
    /// must not make the next pull fetch everything again.
    public mutating func advanceCursor(for table: String, to seq: Int64) {
        if seq > cursor(for: table) { cursors[table] = seq }
    }

    // MARK: Rows

    public func fingerprint(table: String, id: String) -> String? {
        known[table]?[id]
    }

    public func isKnown(table: String, id: String) -> Bool {
        fingerprint(table: table, id: id) != nil
    }

    /// Whether a local row needs pushing: the server has never seen it, or it
    /// changed since the last push or pull.
    public func isDirty(table: String, id: String, fingerprint: String) -> Bool {
        self.fingerprint(table: table, id: id) != fingerprint
    }

    /// Records a row as the server now holds it — after a successful push, or
    /// after applying a pulled row.
    public mutating func record(table: String, id: String, fingerprint: String) {
        known[table, default: [:]][id] = fingerprint
    }

    public mutating func forget(table: String, id: String) {
        known[table]?[id] = nil
    }

    /// Ids the server holds that no longer exist here: rows deleted on this
    /// device since the last sync, which need a soft delete pushed.
    public func deletedLocally(table: String, localIDs: Set<String>) -> [String] {
        (known[table] ?? [:]).keys.filter { !localIDs.contains($0) }.sorted()
    }
}

/// What to do with one pulled row (contracts §2: last write wins in server order).
public enum SyncMergeDecision: Equatable, Sendable {
    /// Not here yet: create it.
    case insert
    /// Here and unchanged locally: take the server's version.
    case update
    /// Here and edited locally since the last push. The local edit is pushed
    /// on the next pass and, being the later write, wins.
    case keepLocal
    /// Deleted on another device, and not edited here since.
    case deleteLocal
    /// Deleted on another device and never seen here: nothing to do.
    case skip
}

public enum SyncMerge {
    public static func decide(localExists: Bool, localDirty: Bool, remoteDeleted: Bool) -> SyncMergeDecision {
        switch (localExists, remoteDeleted) {
        case (false, true): .skip
        case (false, false): .insert
        case (true, _) where localDirty: .keepLocal
        case (true, true): .deleteLocal
        case (true, false): .update
        }
    }

    /// Whether a page was the last one: a short page means the table is drained.
    public static func isLastPage(rowCount: Int, pageSize: Int) -> Bool {
        rowCount < pageSize
    }
}

/// Stable ids for rows that existed before sync did.
public enum SyncIdentity {
    /// Positions whose id repeats an earlier one and must be replaced.
    ///
    /// When `id` was added to the SwiftData models, the store gave every
    /// existing row the *same* default UUID — a schema default is evaluated
    /// once, not per row. The first holder keeps it; every later one needs a
    /// fresh id before anything is pushed, or the upserts would overwrite one
    /// another on the server.
    ///
    /// VERIFY: that lightweight migration fills the new `id` column with one
    /// shared default. If it assigns per-row values instead, this finds no
    /// duplicates and costs one fetch per model at the first launch.
    public static func duplicatePositions(in ids: [UUID]) -> [Int] {
        var seen = Set<UUID>()
        var positions: [Int] = []
        for (index, id) in ids.enumerated() where !seen.insert(id).inserted {
            positions.append(index)
        }
        return positions
    }
}

/// Numbers for `DebtRecord.remoteID` (`money_debts.local_id`).
///
/// The payoff engine orders debts by this number, and payments point at a debt
/// through it, so two debts can never share one. Two phones adding a debt
/// offline will both pick `max + 1`; the one that loses is renumbered.
public enum DebtNumbering {
    public static func nextFree(after used: some Sequence<Int>) -> Int {
        (used.max() ?? 0) + 1
    }
}
