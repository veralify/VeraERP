import SwiftUI
import SwiftData
import VeralifyCore

/// Recent receipts, newest first, each with where it has got to.
///
/// Presented as a sheet with its own navigation, so it opens the same way
/// from anywhere; `initialReceipt` opens straight onto one (the receipt just
/// captured).
struct ReceiptsView: View {
    var initialReceipt: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<ReceiptRecord> { $0.deletedAt == nil },
        sort: \ReceiptRecord.createdAt,
        order: .reverse
    )
    private var receipts: [ReceiptRecord]

    @State private var path: [UUID] = []
    @State private var capture: ReceiptCaptureMode?
    @State private var deleting: ReceiptRecord?

    private var queue: ReceiptQueue { ReceiptQueue.shared }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if !queue.isOnline {
                            offlineBanner
                        }
                        if receipts.isEmpty {
                            EmptyStateView(
                                icon: "doc.viewfinder",
                                title: "No receipts yet",
                                message: "Scan a receipt and it is read for you. Offline, it waits on your phone and uploads when you are back online."
                            )
                        } else {
                            list
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { capture = .camera } label: {
                            Label("Scan receipt", systemImage: "camera.fill")
                        }
                        .disabled(!ReceiptPageCamera.isSupported)
                        Button { capture = .photos } label: {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.lime)
                    }
                    .accessibilityLabel("Add receipt")
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let record = receipts.first(where: { $0.id == id }) {
                    ReceiptDetailView(record: record)
                } else {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        EmptyStateView(
                            icon: "trash",
                            title: "Receipt deleted",
                            message: "This receipt is no longer on this phone."
                        )
                    }
                }
            }
            .confirmationDialog(
                "Delete this receipt?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let deleting { queue.delete(deleting) }
                    deleting = nil
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: {
                Text("The photo is removed. A transaction already saved from it stays.")
            }
        }
        .receiptCapture(mode: $capture) { record in
            path = [record.id]
        }
        .task {
            queue.attach(context)
            if let initialReceipt, path.isEmpty { path = [initialReceipt] }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.yellow)
            Text("You're offline. New receipts wait here and upload when you're back online.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.yellow.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(receipts.enumerated()), id: \.element.id) { index, record in
                if index > 0 { RowDivider().padding(.horizontal, 14) }
                NavigationLink(value: record.id) {
                    ReceiptListRow(record: record, isOnline: queue.isOnline)
                }
                .buttonStyle(.pressableRow)
                .contextMenu {
                    Button(role: .destructive) { deleting = record } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// One receipt in the list: its first page, what it says, and its state.
struct ReceiptListRow: View {
    let record: ReceiptRecord
    let isOnline: Bool

    var body: some View {
        let extraction = record.extraction
        HStack(spacing: 12) {
            ReceiptThumbnail(record: record, side: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(extraction?.merchant.name.value ?? String(localized: "Receipt"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(detail(extraction))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ReceiptStatusPill(record: record, isOnline: isOnline)
        }
        .padding(14)
        .contentShape(.rect)
    }

    private func detail(_ extraction: ReceiptExtraction?) -> String {
        let captured = record.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        guard let extraction, let total = extraction.totalAmount else { return captured }
        let amount = total.formatted(
            .currency(code: extraction.currencyCode ?? AppSettings.currencyCode)
                .locale(Locale(identifier: "en_US"))
        )
        let day = extraction.occurredAt()?.formatted(.dateTime.day().month(.abbreviated)) ?? captured
        return "\(day) · \(amount)"
    }
}

/// Where a receipt has got to, in the pill style the rest of the app uses.
struct ReceiptStatusPill: View {
    let record: ReceiptRecord
    let isOnline: Bool

    var body: some View {
        Pill(text: label.text, style: .muted(dot: label.dot))
    }

    private var label: (text: String, dot: Color) {
        switch record.status.phase {
        case .uploading:
            return isOnline
                ? (String(localized: "Uploading"), Theme.blue)
                : (String(localized: "Waiting"), Theme.textTertiary)
        case .reading:
            return (String(localized: "Reading"), Theme.blue)
        case .needsReview:
            return (String(localized: "Check"), Theme.yellow)
        case .done:
            return (String(localized: "Saved"), Theme.green)
        case .failed:
            return record.nextAttemptAt != nil
                ? (String(localized: "Retrying"), Theme.yellow)
                : (String(localized: "Failed"), Theme.red)
        }
    }
}

/// The first page, small, or a placeholder until there is one.
struct ReceiptThumbnail: View {
    let record: ReceiptRecord
    let side: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.surfaceElevated)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: side * 0.4, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: side, height: side * 1.3)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
        .task(id: record.id) {
            image = await ReceiptPages.thumbnail(for: record, side: side * 2)
        }
    }
}
