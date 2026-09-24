import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for one document.
struct DocumentRoute: Hashable {
    let id: UUID
}

/// Saved identity documents: what they are, when they expire, and every field
/// one tap from the clipboard.
///
/// Content only — the title and the tab bar belong to `MainTabView`. This was a
/// row inside the Account sheet, filed next to "Delete all data"; it is a
/// reason to open the app, so it is a place you can reach from the front door.
struct IDVaultView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredDocument.createdAt, order: .reverse) private var documents: [StoredDocument]

    @State private var notifications = NotificationManager()
    @State private var isScanning = false
    @State private var pendingScan: ScannedDocument?
    @State private var toast: String?
    @State private var scanError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            if documents.isEmpty {
                // Centred in the space above the floating tab bar, like the
                // other tabs' empty states, rather than dropped to the bottom
                // by the ZStack's alignment. Scrollable, because at the largest
                // text sizes the copy and both buttons outgrow a small screen.
                GeometryReader { proxy in
                    ScrollView {
                        emptyState
                            .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 92))
                            // Clear of the floating tab bar, which this screen
                            // sits behind rather than being pushed above.
                            .padding(.bottom, 92)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        if notifications.permission == .denied { permissionBanner }
                        wallet
                        scanButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 108)
                }
                .scrollIndicators(.hidden)
            }

            if let toast {
                CopyToast(text: toast)
                    .padding(.bottom, 116)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: toast)
        .navigationDestination(for: DocumentRoute.self) { route in
            if let document = documents.first(where: { $0.id == route.id }) {
                DocumentDetailView(document: document, notifications: notifications)
            } else {
                // Deleting a document from its own screen takes it out of the
                // query, and the screen is about a document that no longer
                // exists. Leave, rather than sit on a blank page.
                DeletedDocumentScreen()
            }
        }
        .task {
            await notifications.refreshPermission()
        }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScannerView { result in
                isScanning = false
                switch result {
                case .success(let scanned): pendingScan = scanned
                case .failure(let error):
                    if case ReceiptScanError.cancelled = error { return }
                    scanError = String(localized: "Couldn't read that document. You can enter it by hand.")
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { pendingScan != nil }, set: { if !$0 { pendingScan = nil } })) {
            if let scanned = pendingScan {
                DocumentReviewSheet(scanned: scanned, notifications: notifications) { saved in
                    context.insert(saved)
                    try? context.save()
                    pendingScan = nil
                    Task { await notifications.reschedule(for: saved) }
                }
                .presentationBackground(Theme.background)
            }
        }
        .alert(
            "Scan failed",
            isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })
        ) {
            Button("Add by hand") { pendingScan = ScannedDocument() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanError ?? "")
        }
    }

    /// The cards, overlapping the way they sit in a wallet.
    ///
    /// Each one is a navigation link rather than an inline expansion: a document
    /// has a photo, six fields and its reminders, which is a screen's worth, and
    /// growing a card in place would push everything below it around.
    private var wallet: some View {
        VStack(spacing: 22) {
            ForEach(Array(grouped.enumerated()), id: \.element.type) { _, group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.lime)
                        Text(group.type.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        Text("\(group.documents.count)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Negative spacing is what makes a stack read as a stack:
                    // every card but the last shows only its top strip, with the
                    // one in front overlapping it.
                    VStack(spacing: -(DocumentCardFace.height - DocumentCardFace.collapsedHeight)) {
                        ForEach(Array(group.documents.enumerated()), id: \.element.id) { index, document in
                            NavigationLink(value: DocumentRoute(id: document.id)) {
                                DocumentCardFace(document: document)
                            }
                            .buttonStyle(.pressable)
                            .zIndex(Double(index))
                        }
                    }
                }
            }
        }
    }

    /// Documents by kind, so a wallet of six reads as three small stacks rather
    /// than one long pile.
    private var grouped: [(type: DocumentType, documents: [StoredDocument])] {
        DocumentType.allCases.compactMap { type in
            let matching = documents.filter { $0.documentType == type }
            return matching.isEmpty ? nil : (type, matching)
        }
    }

    private func show(toast value: String) {
        toast = value
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            toast = nil
        }
    }

    // MARK: - Pieces

    private var emptyState: some View {
        VStack(spacing: 18) {
            EmptyStateView(
                icon: "person.text.rectangle",
                title: "No documents yet",
                message: "Scan a passport or ID and Veralify keeps its details to hand — and reminds you before it expires."
            )
            scanButton
            Text("Everything stays on this device, behind your passcode. Photos are yours to add or leave out.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var scanButton: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: "Scan a document", enabled: DocumentScannerView.isSupported) {
                isScanning = true
            }
            if !DocumentScannerView.isSupported {
                Text("Scanning needs a camera, so it only works on a device.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { pendingScan = ScannedDocument() } label: {
                Text("Add by hand")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.lime)
                    // The bare text was a 20pt target; this keeps it looking
                    // like a link while giving the thumb a full row.
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
        }
    }

    private var permissionBanner: some View {
        AlertBanner(
            icon: "bell.slash.fill",
            title: "Reminders are off",
            message: "Turn on notifications in Settings and Veralify can warn you before a document expires.",
            accent: Theme.yellow
        )
    }
}

/// Stands in for a document that was deleted while its screen was open, just
/// long enough to pop back to the wallet.
private struct DeletedDocumentScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Theme.background
            .ignoresSafeArea()
            .onAppear { dismiss() }
    }
}
