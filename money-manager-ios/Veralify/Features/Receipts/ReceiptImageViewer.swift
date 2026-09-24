import SwiftUI
import PDFKit
import VeralifyCore

/// A receipt's pages as images, wherever they are.
///
/// Captured on this phone: straight from Application Support. Captured on
/// another device or e-mailed in: fetched from storage once and cached under
/// `cached-{page}` names — kept apart from `localImageNames`, which the upload
/// queue reads as "pages this phone still has to send".
@MainActor
enum ReceiptPages {

    static func images(for record: ReceiptRecord) async -> [UIImage] {
        if !record.localImageNames.isEmpty {
            return record.localImageNames.compactMap { ReceiptImageStore.image(receiptID: record.id, name: $0) }
        }
        var images: [UIImage] = []
        for (index, path) in record.imagePaths.enumerated() {
            images += await remotePage(receiptID: record.id, path: path, page: index + 1)
        }
        return images
    }

    static func thumbnail(for record: ReceiptRecord, side: CGFloat) async -> UIImage? {
        if let first = record.localImageNames.first {
            return ReceiptImageStore.thumbnail(receiptID: record.id, name: first, side: side)
        }
        guard let path = record.imagePaths.first else { return nil }
        return await remotePage(receiptID: record.id, path: path, page: 1).first?
            .preparingThumbnail(of: CGSize(width: side, height: side * 1.4))
    }

    /// One stored object as images: one for a photo, one per page for a PDF.
    private static func remotePage(receiptID: UUID, path: String, page: Int) async -> [UIImage] {
        let isPDF = path.lowercased().hasSuffix(".pdf")
        let name = "cached-\(page).\(isPDF ? "pdf" : "img")"
        var data = ReceiptImageStore.data(receiptID: receiptID, name: name)
        if data == nil, let api = try? ReceiptAPI.current(), let fetched = try? await api.downloadPage(path: path) {
            _ = try? ReceiptImageStore.cache(fetched, receiptID: receiptID, name: name)
            data = fetched
        }
        guard let bytes = data else { return [] }
        if isPDF { return pdfPages(bytes) }
        return UIImage(data: bytes).map { [$0] } ?? []
    }

    /// PDFs arrive by e-mail; rendered at a readable size for review.
    private static func pdfPages(_ data: Data) -> [UIImage] {
        guard let document = PDFDocument(data: data) else { return [] }
        return (0..<min(document.pageCount, 10)).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let scale = 1600 / max(bounds.width, bounds.height, 1)
            return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
        }
    }
}

/// The pages full screen, swipe between them, pinch or double-tap to zoom —
/// for checking a figure the AI was unsure of against the paper.
struct ReceiptImageViewer: View {
    let record: ReceiptRecord
    var startPage: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var images: [UIImage] = []
    @State private var page = 0
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if images.isEmpty {
                Text("The photo isn't available on this phone.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $page) {
                    ForEach(images.indices, id: \.self) { index in
                        ZoomableImage(image: images[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
                .ignoresSafeArea()
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceElevated.opacity(0.9), in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .padding(12)
            .accessibilityLabel("Close")
        }
        .task {
            images = await ReceiptPages.images(for: record)
            page = min(startPage, max(images.count - 1, 0))
            isLoading = false
        }
    }
}

/// Pinch to zoom, drag to pan once zoomed, double-tap to toggle.
///
/// The drag is only attached while zoomed in: attached always, it would eat
/// the horizontal swipe the page view needs to move between pages.
struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    private let maxScale: CGFloat = 6

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(settledScale * value.magnification, 1), maxScale)
                    }
                    .onEnded { _ in
                        settledScale = scale
                        if scale <= 1 { reset() }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: settledOffset.width + value.translation.width,
                            height: settledOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in settledOffset = offset },
                including: scale > 1 ? .all : .subviews
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy(duration: 0.25)) {
                    if scale > 1 {
                        reset()
                    } else {
                        scale = 2.5
                        settledScale = 2.5
                    }
                }
            }
            .accessibilityLabel(Text("Receipt photo"))
            .accessibilityAddTraits(.isImage)
    }

    private func reset() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
    }
}
