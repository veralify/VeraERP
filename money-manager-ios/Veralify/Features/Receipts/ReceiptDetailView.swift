import SwiftUI
import SwiftData
import VeralifyCore

/// One receipt. While it travels it says where it is; once read it becomes
/// the review form; once saved, a summary.
struct ReceiptDetailView: View {
    let record: ReceiptRecord

    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    private var queue: ReceiptQueue { ReceiptQueue.shared }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { isConfirmingDelete = true } label: {
                        Label("Delete receipt", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Delete this receipt?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                queue.delete(record)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo is removed. A transaction already saved from it stays.")
        }
    }

    private var title: LocalizedStringKey {
        switch record.status.phase {
        case .needsReview: "Check receipt"
        case .done: "Saved receipt"
        default: "Receipt"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch record.status.phase {
        case .needsReview:
            if let extraction = record.extraction {
                ReceiptReviewForm(record: record, extraction: extraction)
            } else {
                // Read by a newer server in a shape this build does not know.
                ReceiptProgressView(record: record, isOnline: queue.isOnline)
            }
        case .done:
            ReceiptSavedView(record: record)
        case .uploading, .reading, .failed:
            ReceiptProgressView(record: record, isOnline: queue.isOnline)
        }
    }
}

/// The receipt on its way: its pages, a clear state, and a retry when stuck.
struct ReceiptProgressView: View {
    let record: ReceiptRecord
    let isOnline: Bool

    @State private var viewingPage: Int?

    private var queue: ReceiptQueue { ReceiptQueue.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ReceiptPageStrip(record: record) { viewingPage = $0 }

                VStack(spacing: 12) {
                    stateIcon
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                if record.status == .failed || record.extractionData != nil && record.extraction == nil {
                    PrimaryButton(title: "Try again") { queue.retry(record) }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(item: Binding(
            get: { viewingPage.map(PageIndex.init) },
            set: { viewingPage = $0?.value }
        )) { index in
            ReceiptImageViewer(record: record, startPage: index.value)
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch record.status.phase {
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.red)
        case .uploading where !isOnline:
            Image(systemName: "wifi.slash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.yellow)
        default:
            ProgressView()
                .controlSize(.large)
                .tint(Theme.lime)
        }
    }

    private var headline: LocalizedStringKey {
        switch record.status.phase {
        case .uploading: isOnline ? "Uploading" : "Waiting for a connection"
        case .reading: "Reading the receipt"
        case .failed: record.nextAttemptAt != nil ? "Couldn't read it yet" : "Couldn't read this receipt"
        case .needsReview: "This receipt needs an update"
        case .done: "Saved"
        }
    }

    /// Plain words for each failure the queue records.
    private var explanation: LocalizedStringKey {
        switch record.status.phase {
        case .uploading:
            return isOnline
                ? "Sending the photo securely. You can close this — it carries on."
                : "The receipt is saved on your phone and uploads as soon as you're back online."
        case .reading:
            return "The AI is reading the merchant, date, total and tax. This usually takes a few seconds."
        case .needsReview:
            return "This receipt was read in a newer format. Update the app to review it."
        case .done:
            return ""
        case .failed:
            switch record.errorCode {
            case "UNREADABLE":
                return "No receipt could be found in the photo. Try again with the whole receipt flat and in focus."
            case "SCAN_LIMIT_REACHED":
                return "You've used this month's receipt scans. They reset on the 1st."
            case "AI_UNAVAILABLE", "RATE_LIMITED", "RECEIPT_BUSY":
                return record.nextAttemptAt != nil
                    ? "Reading is busy right now. It will try again by itself shortly."
                    : "Reading is busy right now. Try again in a moment."
            case "LOCAL_IMAGE_MISSING":
                return "The photo is no longer on this phone. Delete this receipt and scan it again."
            default:
                return record.nextAttemptAt != nil
                    ? "Something went wrong sending it. It will try again by itself shortly."
                    : "Something went wrong sending it. Try again."
            }
        }
    }
}

/// A confirmed receipt: what was saved from it, and the photo for the records.
struct ReceiptSavedView: View {
    let record: ReceiptRecord

    @State private var viewingPage: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ReceiptPageStrip(record: record) { viewingPage = $0 }

                if let extraction = record.extraction {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(extraction.merchant.name.value ?? String(localized: "Receipt"))
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer(minLength: 8)
                            Pill(text: String(localized: "Saved"), style: .muted(dot: Theme.green))
                        }
                        if let total = extraction.totalAmount {
                            Text(total.formatted(
                                .currency(code: extraction.currencyCode ?? AppSettings.currencyCode)
                                    .locale(Locale(identifier: "en_US"))
                            ))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        }
                        Text("Saved as a transaction. Edit it from your entries.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(item: Binding(
            get: { viewingPage.map(PageIndex.init) },
            set: { viewingPage = $0?.value }
        )) { index in
            ReceiptImageViewer(record: record, startPage: index.value)
        }
    }
}

/// `Int` wrapped for `fullScreenCover(item:)`.
struct PageIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

/// The receipt's pages in a row; tap one to see it full screen.
struct ReceiptPageStrip: View {
    let record: ReceiptRecord
    let onOpen: (Int) -> Void

    @State private var images: [UIImage] = []

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                if images.isEmpty {
                    RoundedRectangle(cornerRadius: Theme.Radius.inner)
                        .fill(Theme.surface)
                        .frame(width: 96, height: 128)
                        .overlay {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                }
                ForEach(images.indices, id: \.self) { index in
                    Button { onOpen(index) } label: {
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 128)
                            .clipShape(.rect(cornerRadius: Theme.Radius.inner))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.inner)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .padding(6)
                                    .background(.black.opacity(0.55), in: .circle)
                                    .padding(6)
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text("Page \(index + 1), open full screen"))
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: record.id) {
            let pages = await ReceiptPages.images(for: record)
            images = pages.map { $0.preparingThumbnail(of: CGSize(width: 192, height: 256)) ?? $0 }
        }
    }
}
