import SwiftUI
import SwiftData
import VeralifyCore

@main
struct VeralifyApp: App {
    private let container: ModelContainer
    @State private var auth: AuthModel
    @State private var sync: SyncEngine

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: DebtRecord.self, IncomeSource.self, ExpenseItem.self, PlanSettings.self,
                TransactionRecord.self, QuestCompletion.self,
                DebtPayment.self, MonthlySnapshot.self,
                FamilyMember.self, FamilyExpense.self, FamilySettlement.self,
                StoredDocument.self, CategoryBudget.self,
                IncomeActual.self, MoneyLoss.self,
                // Sync: categories and merchant rules pulled from the account,
                // the sync ledger, and receipts (defined by receipt capture).
                MoneyCategory.self, MerchantRule.self, SyncStateRecord.self,
                ReceiptRecord.self
            )
        } catch {
            // A store that cannot open is unrecoverable and silently showing an
            // empty app would look like data loss, so fail loudly in debug.
            fatalError("Could not open the Veralify store: \(error)")
        }

        self.container = container
        Self.protectStore(container)

        // Before any screen reads the store: rows written before sync existed
        // need unique ids (see `SyncMigration`).
        SyncMigration.runIfNeeded(in: container.mainContext)

        // The backend comes from build settings, never from source. A build
        // without them opens onto a screen that says what is missing rather
        // than crashing, so the rest of the app can still be worked on.
        let backend: SupabaseBackend?
        let problem: String?
        do {
            backend = SupabaseBackend(configuration: try SupabaseBackend.bundleConfiguration())
            problem = nil
        } catch {
            backend = nil
            problem = String(describing: error)
        }
        Backend.session = backend

        let engine = SyncEngine(container: container)
        engine.observeLocalSaves()
        _auth = State(initialValue: AuthModel(backend: backend, configurationProblem: problem))
        _sync = State(initialValue: engine)
    }

    /// Makes the store unreadable while the phone is locked.
    ///
    /// SwiftData holds passport numbers, dates of birth and names once the
    /// document vault is used — enough, together, to impersonate someone. iOS
    /// defaults to `.completeUntilFirstUserAuthentication`, which leaves the
    /// file readable from the first unlock after a reboot until power-off.
    /// `.completeUnlessOpen` keeps it sealed whenever the device is locked.
    ///
    /// Applied to the container's own URL rather than a path of our choosing:
    /// naming a store would move it, and moving it would orphan every record
    /// already saved.
    private static func protectStore(_ container: ModelContainer) {
        guard let url = container.configurations.first?.url else { return }

        let manager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUnlessOpen
        ]

        // SQLite keeps its write-ahead log and shared memory beside the store,
        // and they hold the same rows. Protecting only the .store leaves recent
        // writes readable in the -wal.
        for path in [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")] {
            guard manager.fileExists(atPath: path.path(percentEncoded: false)) else { continue }
            try? manager.setAttributes(attributes, ofItemAtPath: path.path(percentEncoded: false))
        }

        // Document photos are `.externalStorage`, so SwiftData writes them as
        // separate files in this directory rather than into the database. A
        // directory's protection class is inherited by files created inside it,
        // which is what covers a photo saved later in the session.
        let directory = url.deletingLastPathComponent()
        try? manager.setAttributes(attributes, ofItemAtPath: directory.path(percentEncoded: false))

        if let existing = try? manager.contentsOfDirectory(atPath: directory.path(percentEncoded: false)) {
            for name in existing {
                let path = directory.appendingPathComponent(name).path(percentEncoded: false)
                try? manager.setAttributes(attributes, ofItemAtPath: path)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(sync)
        }
        .modelContainer(container)
    }
}
