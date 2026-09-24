import Foundation
import Network
import SwiftData
import UIKit
import VeralifyCore

/// Takes captured receipts from the phone to a reading the user can review,
/// whenever there is a connection.
///
/// A receipt is saved locally the moment it is captured, so nothing is lost
/// on a train or abroad without data. The queue then walks each one through
/// `ReceiptProgress.nextStep` — create the row, upload each page, save the
/// paths, ask the gateway to read it — saving after every step, so a receipt
/// interrupted halfway resumes at the step it stopped on rather than from the
/// start. Every step is idempotent on the server for the same reason.
///
/// Main-actor because it works on SwiftData records from the main context;
/// the network calls themselves run off it (`ReceiptAPI` is nonisolated).
@MainActor
@Observable
final class ReceiptQueue {
    static let shared = ReceiptQueue()

    private(set) var isOnline = true
    private(set) var isRunning = false

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    /// Called by every receipts screen as it appears. The first context wins;
    /// it is the app's main context, whichever screen hands it over.
    func attach(_ context: ModelContext) {
        if self.context == nil { self.context = context }
        startMonitoring()
        kick()
    }

    /// Runs a pass now, or right after the one in progress.
    func kick() {
        guard context != nil else { return }
        if runTask != nil {
            needsAnotherPass = true
            return
        }
        runTask = Task {
            await run()
            runTask = nil
        }
    }

    // MARK: User actions

    /// Saves a new receipt from captured page images and starts on it.
    @discardableResult
    func capture(pages: [Data], source: String, in context: ModelContext) throws -> ReceiptRecord {
        let id = UUID()
        let names = try ReceiptImageStore.save(pages: pages, receiptID: id)
        let record = ReceiptRecord(id: id, source: source, localImageNames: names)
        context.insert(record)
        try context.save()
        attach(context)
        kick()
        return record
    }

    /// Tries a failed receipt again from the step it failed on.
    func retry(_ record: ReceiptRecord) {
        record.errorCode = nil
        record.attemptCount = 0
        record.nextAttemptAt = nil
        record.status = resumeStatus(for: record)
        try? context?.save()
        kick()
    }

    /// Removes a receipt. One the server never saw goes at once; otherwise it
    /// is soft-deleted and the deletion is sent, so other devices drop it too.
    func delete(_ record: ReceiptRecord) {
        ReceiptImageStore.delete(receiptID: record.id)
        if !record.isKnownToServer {
            context?.delete(record)
        } else {
            record.deletedAt = .now
            record.updatedAt = .now
            record.needsPush = true
        }
        try? context?.save()
        kick()
    }

    // MARK: The pass

    private func run() async {
        isRunning = true
        beginBackgroundTask()
        repeat {
            needsAnotherPass = false
            await pass()
        } while needsAnotherPass && isOnline
        isRunning = false
        endBackgroundTask()
        scheduleWake()
    }

    private func pass() async {
        guard let context, isOnline else { return }
        let api: ReceiptAPI
        do {
            api = try ReceiptAPI.current()
        } catch {
            return // Signed out, or sign-in not set up yet: nothing can be sent.
        }
        guard let userID = await api.session.userID else { return }

        let all = (try? context.fetch(FetchDescriptor<ReceiptRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []

        // Deletions first: no point uploading a receipt the user threw away.
        for record in all where record.deletedAt != nil && record.needsPush {
            do {
                try await api.deleteReceipt(id: record.id, at: record.deletedAt ?? .now)
                record.needsPush = false
                try? context.save()
            } catch {
                return
            }
        }

        for record in all where record.deletedAt == nil && record.pendingRuleCategoryKey != nil {
            guard await pushRule(for: record, api: api, userID: userID) else { return }
        }

        let now = Date.now
        for record in all where record.deletedAt == nil && isDue(record, at: now) {
            if record.status == .failed { record.status = resumeStatus(for: record) }
            guard await advance(record, api: api, userID: userID) else { return }
        }
    }

    private func isDue(_ record: ReceiptRecord, at now: Date) -> Bool {
        if record.status.isPending { return (record.nextAttemptAt ?? .distantPast) <= now }
        if record.status == .failed, let next = record.nextAttemptAt { return next <= now }
        return false
    }

    /// Where a failed receipt picks up again.
    private func resumeStatus(for record: ReceiptRecord) -> ReceiptStatus {
        let progress = record.progress
        if !progress.rowCreated { return .captured }
        if !progress.pathsSaved { return .uploading }
        return .uploaded
    }

    /// Walks one receipt as far as it will go. Returns false when the whole
    /// pass should stop (offline, signed out) rather than just this receipt.
    private func advance(_ record: ReceiptRecord, api: ReceiptAPI, userID: UUID) async -> Bool {
        guard let context else { return false }
        do {
            while true {
                switch record.progress.nextStep {
                case .nothing:
                    return true

                case .createRow:
                    record.status = .uploading
                    try await api.createReceipt(id: record.id, userID: userID, source: record.sourceRaw)
                    record.rowCreated = true

                case .uploadPage(let page):
                    record.status = .uploading
                    let name = record.localImageNames[page - 1]
                    guard let data = ReceiptImageStore.data(receiptID: record.id, name: name) else {
                        // The photo is gone from the phone; nothing can bring it back.
                        fail(record, code: "LOCAL_IMAGE_MISSING", retry: false)
                        try? context.save()
                        return true
                    }
                    try await api.uploadPage(
                        data,
                        path: ReceiptStorage.path(userID: userID, receiptID: record.id, page: page)
                    )
                    record.uploadedPageCount = page

                case .savePaths:
                    let paths = (1...record.localImageNames.count).map {
                        ReceiptStorage.path(userID: userID, receiptID: record.id, page: $0)
                    }
                    try await api.saveImagePaths(receiptID: record.id, paths: paths)
                    record.imagePaths = paths
                    record.needsPush = false
                    record.status = .uploaded

                case .read:
                    record.status = .processing
                    try? context.save()
                    let (_, raw) = try await api.extract(
                        receiptID: record.id,
                        locale: Locale.current.identifier(.bcp47),
                        homeCurrency: AppSettings.currencyCode
                    )
                    record.extractionData = raw
                    record.errorCode = nil
                    record.attemptCount = 0
                    record.nextAttemptAt = nil
                    record.status = .extracted
                }
                try? context.save()
            }
        } catch ReceiptAPI.APIError.offline {
            try? context.save()
            return false
        } catch ReceiptAPI.APIError.signedOut {
            return false
        } catch ReceiptAPI.APIError.gateway(let error) {
            switch error {
            case .unauthenticated:
                try? context.save()
                return false
            case .imagesMissing:
                // Storage lost a page the row lists: upload them all again.
                record.uploadedPageCount = 0
                record.imagePaths = []
                fail(record, code: error.code, retry: true)
            default:
                fail(record, code: error.code, retry: error.retriesAutomatically)
            }
        } catch ReceiptAPI.APIError.http(let status, _) {
            // A 5xx or no status is the server's trouble and passes; a 4xx
            // will fail the same way next time and waits for the user.
            fail(record, code: "HTTP_\(status)", retry: status == 0 || status >= 500)
        } catch {
            fail(record, code: "UNKNOWN", retry: true)
        }
        try? context.save()
        return true
    }

    private func fail(_ record: ReceiptRecord, code: String, retry: Bool) {
        record.errorCode = code
        record.attemptCount += 1
        record.nextAttemptAt = retry
            ? Date.now.addingTimeInterval(ReceiptRetryPolicy.delay(afterAttempt: record.attemptCount))
            : nil
        record.status = .failed
    }

    private func pushRule(for record: ReceiptRecord, api: ReceiptAPI, userID: UUID) async -> Bool {
        guard let category = record.pendingRuleCategoryKey else { return true }
        let key = record.extraction?.merchantKey ?? ""
        guard !key.isEmpty else {
            record.pendingRuleCategoryKey = nil
            record.pendingRuleScopeRaw = nil
            return true
        }
        do {
            try await api.saveMerchantRule(
                userID: userID,
                merchantKey: key,
                categoryKey: category,
                scope: record.pendingRuleScopeRaw
            )
            record.pendingRuleCategoryKey = nil
            record.pendingRuleScopeRaw = nil
            try? context?.save()
            return true
        } catch ReceiptAPI.APIError.offline {
            return false
        } catch {
            // A rule is a convenience; one the server refuses is dropped rather
            // than retried forever.
            record.pendingRuleCategoryKey = nil
            record.pendingRuleScopeRaw = nil
            try? context?.save()
            return true
        }
    }

    // MARK: Waking up

    /// Sleeps until the earliest automatic retry is due, then runs again.
    private func scheduleWake() {
        wakeTask?.cancel()
        guard let context else { return }
        let all = (try? context.fetch(FetchDescriptor<ReceiptRecord>())) ?? []
        guard let next = all.compactMap(\.nextAttemptAt).filter({ $0 > .now }).min() else { return }
        let delay = max(1, next.timeIntervalSinceNow)
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.kick()
        }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in ReceiptQueue.shared.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "com.veralify.receipts.network"))
        self.monitor = monitor
    }

    private func networkChanged(online: Bool) {
        let cameBack = online && !isOnline
        isOnline = online
        if cameBack { kick() }
    }

    // MARK: Background time

    /// Asks for a little time to finish an upload if the app is sent to the
    /// background mid-way; a half-uploaded receipt would otherwise wait for
    /// the next launch.
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "receipt-upload") { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
