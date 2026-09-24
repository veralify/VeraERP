import SwiftUI
import SwiftData
import VeralifyCore

/// The Today screen's way in to receipts: scan one, pick one from Photos, or
/// open the ones already captured.
///
/// Self-contained — it owns its capture flow and its sheet — so the
/// dashboard only has to place it.
struct ScanReceiptEntry: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<ReceiptRecord> { $0.deletedAt == nil },
        sort: \ReceiptRecord.createdAt,
        order: .reverse
    )
    private var receipts: [ReceiptRecord]

    @State private var capture: ReceiptCaptureMode?
    @State private var presented: ReceiptsSheetRoute?

    private var queue: ReceiptQueue { ReceiptQueue.shared }

    private var toReview: Int { receipts.filter { $0.status.phase == .needsReview }.count }
    private var inFlight: Int {
        receipts.filter { [.uploading, .reading].contains($0.status.phase) }.count
    }
    private var failed: Int { receipts.filter { $0.status.phase == .failed }.count }

    /// One line on where things stand, most urgent first.
    private var summary: String {
        if toReview > 0 {
            return String(localized: "\(toReview) ready to check")
        }
        if inFlight > 0 {
            return queue.isOnline
                ? String(localized: "\(inFlight) being read")
                : String(localized: "\(inFlight) waiting for a connection")
        }
        if failed > 0 {
            return String(localized: "\(failed) couldn't be read")
        }
        return String(localized: "Read by AI, filed for you to check")
    }

    private var summaryTint: Color {
        if toReview > 0 { return Theme.yellow }
        if failed > 0 && inFlight == 0 { return Theme.red }
        return Theme.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { presented = .list } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                        .frame(width: 38, height: 38)
                        .background(Theme.lime.opacity(0.14), in: .circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receipts")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(summaryTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressableRow)
            .accessibilityHint(Text("Shows your scanned receipts"))

            HStack(spacing: 10) {
                Button { capture = .camera } label: {
                    Label("Scan receipt", systemImage: "camera.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.lime, in: .capsule)
                }
                .buttonStyle(.pressable)
                .disabled(!ReceiptPageCamera.isSupported)
                .opacity(ReceiptPageCamera.isSupported ? 1 : 0.5)

                Button { capture = .photos } label: {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(Theme.surfaceElevated, in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }

            if !ReceiptPageCamera.isSupported {
                // True on every simulator, where this is first tried.
                Text("Scanning needs a camera, so it only works on a device. Photos works everywhere.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .receiptCapture(mode: $capture) { record in
            presented = .receipt(record.id)
        }
        .sheet(item: $presented) { route in
            ReceiptsView(initialReceipt: route.receiptID)
                .presentationBackground(Theme.background)
        }
        .task { queue.attach(context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { queue.kick() }
        }
    }
}

/// What the receipts sheet opens on.
enum ReceiptsSheetRoute: Identifiable, Hashable {
    case list
    case receipt(UUID)

    var id: String {
        switch self {
        case .list: "list"
        case .receipt(let id): id.uuidString
        }
    }

    var receiptID: UUID? {
        if case .receipt(let id) = self { return id }
        return nil
    }
}
