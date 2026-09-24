import Foundation
import UIKit
import VeralifyCore

/// Receipt page images on the phone: Application Support/Receipts/{id}/{page}.jpg.
///
/// Files rather than SwiftData `.externalStorage`: the upload queue streams
/// them to storage by URL, and a pulled receipt's pages are cached here by the
/// same names. Protected like the store itself (see `VeralifyApp.protectStore`)
/// — a receipt can carry a card's last digits and a home address.
enum ReceiptImageStore {

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Receipts", isDirectory: true)
    }

    static func directory(for receiptID: UUID) -> URL {
        root.appendingPathComponent(receiptID.uuidString.lowercased(), isDirectory: true)
    }

    static func url(receiptID: UUID, name: String) -> URL {
        directory(for: receiptID).appendingPathComponent(name)
    }

    /// Scales a page down to the contract's size and encodes it as JPEG.
    ///
    /// Drawn at scale 1 so the pixel size is exactly what `targetSize` says —
    /// the renderer otherwise multiplies by the screen scale and a 1600px page
    /// comes out at 4800.
    @MainActor
    static func jpegData(from image: UIImage) -> Data? {
        let pixelWidth = Double(image.size.width * image.scale)
        let pixelHeight = Double(image.size.height * image.scale)
        let target = ReceiptStorage.targetSize(width: pixelWidth, height: pixelHeight)
        let size = CGSize(width: target.width, height: target.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // `draw(in:)` applies the image's orientation, so a photo taken in
            // portrait is stored upright rather than relying on EXIF.
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: ReceiptStorage.jpegQuality)
    }

    /// Writes the pages for a new receipt and returns their file names, in order.
    static func save(pages: [Data], receiptID: UUID) throws -> [String] {
        let directory = directory(for: receiptID)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        var names: [String] = []
        for (index, data) in pages.enumerated() {
            let name = "\(index + 1).jpg"
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUnlessOpen])
            names.append(name)
        }
        return names
    }

    /// Caches a page fetched from storage (a receipt from another device or
    /// from e-mail), under a name the upload queue never reads.
    static func cache(_ data: Data, receiptID: UUID, name: String) throws -> String {
        let directory = directory(for: receiptID)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUnlessOpen])
        return name
    }

    static func data(receiptID: UUID, name: String) -> Data? {
        try? Data(contentsOf: url(receiptID: receiptID, name: name))
    }

    static func image(receiptID: UUID, name: String) -> UIImage? {
        UIImage(contentsOfFile: url(receiptID: receiptID, name: name).path(percentEncoded: false))
    }

    /// A small version for list rows, decoded at display size rather than at
    /// the full 1600px — a list of twenty full pages is 150 MB of bitmaps.
    static func thumbnail(receiptID: UUID, name: String, side: CGFloat) -> UIImage? {
        image(receiptID: receiptID, name: name)?.preparingThumbnail(of: CGSize(width: side, height: side * 1.4))
    }

    static func delete(receiptID: UUID) {
        try? FileManager.default.removeItem(at: directory(for: receiptID))
    }
}
