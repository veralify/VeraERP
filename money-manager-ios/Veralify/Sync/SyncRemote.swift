import Foundation
import Supabase
import VeralifyCore

/// The server side of sync, as three operations. A protocol so the engine
/// does not depend on how requests are made.
protocol SyncRemote: Sendable {
    /// One page of rows with `sync_seq` past `cursor`, oldest first.
    func pull(_ table: SyncTable, after cursor: Int64, userID: UUID) async throws -> [SyncRow]
    /// Inserts or updates rows on the table's conflict target.
    func upsert(_ table: SyncTable, rows: [SyncRow]) async throws
    /// Sets `deleted_at` on rows by id.
    func softDelete(_ table: SyncTable, ids: [String], userID: UUID, at date: Date) async throws
}

/// Why a sync stopped, reduced to what the app can act on.
enum SyncFailure: Error, Equatable {
    /// No connection, or the request timed out. Nothing is lost; the next
    /// trigger retries.
    case offline
    /// The session expired and could not be refreshed.
    case signedOut
    /// The server refused the request.
    case server(String)
}

extension SyncFailure {
    /// Maps any error from the network layer.
    static func from(_ error: Error) -> SyncFailure {
        if let failure = error as? SyncFailure { return failure }
        if error is URLError { return .offline }
        if let backend = error as? BackendError, backend == .signedOut { return .signedOut }
        if let postgrest = error as? PostgrestError {
            return .server([postgrest.code, postgrest.message].compactMap { $0 }.joined(separator: ": "))
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .offline }
        return .server(String(describing: error))
    }

    /// Whether retrying the same request row by row could get part of it
    /// through: a constraint or check failure on one row fails a whole batch,
    /// but a lost connection fails every row the same way.
    var isRowSpecific: Bool {
        if case .server = self { return true }
        return false
    }
}

/// `SyncRemote` over the Supabase client's PostgREST API.
struct SupabaseSyncRemote: SyncRemote {
    let client: SupabaseClient

    func pull(_ table: SyncTable, after cursor: Int64, userID: UUID) async throws -> [SyncRow] {
        do {
            let response = try await client
                .from(table.rawValue)
                .select(table.selectList)
                // RLS already limits rows to the caller; the filter is for the
                // (user_id, sync_seq) index each table has.
                .eq("user_id", value: userID.uuidString.lowercased())
                .gt("sync_seq", value: String(cursor))
                .order("sync_seq", ascending: true)
                .limit(SyncTable.pageSize)
                .execute()
            return try SyncJSON.rows(from: response.data)
        } catch {
            throw SyncFailure.from(error)
        }
    }

    func upsert(_ table: SyncTable, rows: [SyncRow]) async throws {
        guard !rows.isEmpty else { return }
        do {
            // `merge-duplicates` (not ignore): the push is the latest write and
            // must replace what the server holds (contracts §2).
            try await client
                .from(table.rawValue)
                .upsert(rows, onConflict: table.conflictTarget, returning: .minimal)
                .execute()
        } catch {
            throw SyncFailure.from(error)
        }
    }

    func softDelete(_ table: SyncTable, ids: [String], userID: UUID, at date: Date) async throws {
        guard !ids.isEmpty, table.hasID else { return }
        let change: SyncRow = ["deleted_at": .string(SyncFormat.instant(date))]
        do {
            try await client
                .from(table.rawValue)
                .update(change, returning: .minimal)
                .eq("user_id", value: userID.uuidString.lowercased())
                .in("id", values: ids)
                .execute()
        } catch {
            throw SyncFailure.from(error)
        }
    }
}
