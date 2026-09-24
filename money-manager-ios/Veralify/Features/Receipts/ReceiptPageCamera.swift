import SwiftUI
import VisionKit
import UIKit

/// The document camera, returning every page as an image.
///
/// The same `VNDocumentCameraViewController` the split screen's
/// `ReceiptScanner` uses — edge detection, perspective correction, multi-page
/// capture — but that one reads the first page on device and returns text.
/// This one keeps all the pages as images for the AI gateway, because a long
/// supermarket receipt is often two or three photographs.
struct ReceiptPageCamera: UIViewControllerRepresentable {
    /// JPEG pages, already scaled for upload, or nil when the user cancelled.
    let onFinish: @MainActor ([Data]?) -> Void

    /// False on the simulator and devices without a usable camera. The
    /// controller traps if presented anyway, so callers check first.
    static var isSupported: Bool { ReceiptScanner.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    /// Main-actor, unlike `ReceiptScanner.Coordinator`: VisionKit calls these
    /// on the main thread, the scan object is not `Sendable`, and the pages
    /// are encoded right here rather than sent anywhere.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let onFinish: @MainActor ([Data]?) -> Void

        init(onFinish: @escaping @MainActor ([Data]?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Scaled to 1600px as each page is taken out, so at most one
            // full-resolution page is held at a time.
            let pages = (0..<scan.pageCount).compactMap { index in
                ReceiptImageStore.jpegData(from: scan.imageOfPage(at: index))
            }
            onFinish(pages.isEmpty ? nil : pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onFinish(nil)
        }
    }
}
