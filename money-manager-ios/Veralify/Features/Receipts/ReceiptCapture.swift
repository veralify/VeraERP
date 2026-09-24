import SwiftUI
import SwiftData
import PhotosUI
import VeralifyCore

/// The two ways a receipt gets into the app.
enum ReceiptCaptureMode: Identifiable {
    case camera, photos
    var id: Self { self }
}

extension View {
    /// Presents the document camera or the photo picker when `mode` is set,
    /// saves what comes back as receipts, and hands the first one over.
    func receiptCapture(
        mode: Binding<ReceiptCaptureMode?>,
        onCaptured: @escaping @MainActor (ReceiptRecord) -> Void
    ) -> some View {
        modifier(ReceiptCaptureModifier(mode: mode, onCaptured: onCaptured))
    }
}

/// Capture is a modifier rather than a screen so the dashboard card and the
/// receipts list share it, each staying on screen underneath while the
/// camera is up.
private struct ReceiptCaptureModifier: ViewModifier {
    @Binding var mode: ReceiptCaptureMode?
    let onCaptured: @MainActor (ReceiptRecord) -> Void

    @Environment(\.modelContext) private var context
    @State private var pickedItems: [PhotosPickerItem] = []
    /// Several photos picked at once: kept here while the user says whether
    /// they are one long receipt or several receipts.
    @State private var pickedPages: [Data] = []
    @State private var isAskingHowToGroup = false
    @State private var isPreparing = false
    @State private var failureMessage: String?

    /// The same cap the gateway enforces per receipt.
    private let maxPages = 10

    private var cameraBinding: Binding<Bool> {
        Binding(
            get: { mode == .camera },
            set: { if !$0, mode == .camera { mode = nil } }
        )
    }

    private var photosBinding: Binding<Bool> {
        Binding(
            get: { mode == .photos },
            set: { if !$0, mode == .photos { mode = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: cameraBinding) {
                ReceiptPageCamera { pages in
                    mode = nil
                    if let pages { save([pages], source: "camera") }
                }
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: photosBinding,
                selection: $pickedItems,
                maxSelectionCount: maxPages,
                matching: .images
            )
            .onChange(of: pickedItems) { _, items in
                guard !items.isEmpty else { return }
                pickedItems = []
                Task { await load(items) }
            }
            .overlay {
                if isPreparing {
                    ProgressView()
                        .tint(Theme.lime)
                        .padding(22)
                        .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                }
            }
            .confirmationDialog(
                "How should these photos be saved?",
                isPresented: $isAskingHowToGroup,
                titleVisibility: .visible
            ) {
                Button("One receipt with \(pickedPages.count) pages") {
                    save([pickedPages], source: "photo_library")
                    pickedPages = []
                }
                Button("\(pickedPages.count) separate receipts") {
                    save(pickedPages.map { [$0] }, source: "photo_library")
                    pickedPages = []
                }
                Button("Cancel", role: .cancel) { pickedPages = [] }
            } message: {
                Text("A long receipt photographed in parts is one receipt.")
            }
            .alert(
                "Couldn't save the receipt",
                isPresented: Binding(get: { failureMessage != nil }, set: { if !$0 { failureMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failureMessage ?? "")
            }
    }

    /// Decodes and scales the picked photos. Loading goes off the main actor
    /// (it can fetch from iCloud); scaling comes back to it, where UIKit drawing belongs.
    private func load(_ items: [PhotosPickerItem]) async {
        isPreparing = true
        defer { isPreparing = false }
        var pages: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = ReceiptImageStore.jpegData(from: image)
            else { continue }
            pages.append(jpeg)
        }
        guard !pages.isEmpty else {
            failureMessage = String(localized: "Those photos couldn't be opened.")
            return
        }
        if pages.count == 1 {
            save([pages], source: "photo_library")
        } else {
            pickedPages = pages
            isAskingHowToGroup = true
        }
    }

    /// One `ReceiptRecord` per group of pages. The queue takes it from here,
    /// now or whenever the phone is next online.
    private func save(_ receipts: [[Data]], source: String) {
        var first: ReceiptRecord?
        do {
            for pages in receipts {
                let record = try ReceiptQueue.shared.capture(pages: pages, source: source, in: context)
                if first == nil { first = record }
            }
        } catch {
            failureMessage = String(localized: "There isn't enough space on this phone to keep the photo.")
        }
        if let first { onCaptured(first) }
    }
}
