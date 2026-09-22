import SwiftUI
import Vision
import VisionKit
import UIKit

/// The document camera, wrapped for SwiftUI.
///
/// `VNDocumentCameraViewController` gives edge detection, perspective
/// correction and multi-page capture for free, and a receipt photographed at an
/// angle on a restaurant table needs all three. A plain camera picker would
/// hand Vision a trapezoid.
struct ReceiptScanner: UIViewControllerRepresentable {
    /// Recognised lines, top to bottom, or the reason there are none.
    ///
    /// Main-actor because it lands in view state, and `Sendable` because the
    /// recognition it waits on runs off the main thread.
    let onResult: @MainActor @Sendable (Result<[String], Error>) -> Void

    /// False on the simulator and on any device without a usable camera. The
    /// caller must check before presenting — this controller traps rather than
    /// failing gracefully.
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    /// Not `@MainActor`: the delegate protocol is not isolated, and a
    /// main-actor conformance to it is a Swift 6 error. The callbacks do arrive
    /// on the main thread, so each one hops back explicitly to deliver.
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onResult: @MainActor @Sendable (Result<[String], Error>) -> Void

        init(onResult: @escaping @MainActor @Sendable (Result<[String], Error>) -> Void) {
            self.onResult = onResult
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Only the first page. A receipt is one page, and asking Vision to
            // reconcile totals across several is a different feature.
            let deliver = onResult
            guard scan.pageCount > 0, let page = scan.imageOfPage(at: 0).cgImage else {
                Task { @MainActor in deliver(.failure(ReceiptScanError.noImage)) }
                return
            }

            Task {
                do {
                    let lines = try await ReceiptTextRecognizer.lines(in: page)
                    await MainActor.run { deliver(.success(lines)) }
                } catch {
                    await MainActor.run { deliver(.failure(error)) }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            let deliver = onResult
            Task { @MainActor in deliver(.failure(ReceiptScanError.cancelled)) }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            let deliver = onResult
            Task { @MainActor in deliver(.failure(error)) }
        }
    }
}

enum ReceiptScanError: Error {
    case cancelled
    case noImage
    case noTextFound
}

/// Turns a scanned page into lines of text, entirely on device.
///
/// Nothing here touches the network. Vision's text recogniser ships with the
/// OS and runs against local models.
enum ReceiptTextRecognizer {

    /// Recognised text, reassembled into lines in reading order.
    ///
    /// The observations are turned into plain strings inside Vision's own
    /// callback: `VNRecognizedTextObservation` is not `Sendable`, so an array
    /// of them cannot cross back over the continuation.
    static func lines(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                guard !observations.isEmpty else {
                    continuation.resume(throwing: ReceiptScanError.noTextFound)
                    return
                }
                continuation.resume(returning: group(observations))
            }

            request.recognitionLevel = .accurate

            // Off, deliberately. Language correction is built for prose: on a
            // receipt it "fixes" 63,80 into something that was never printed,
            // and mangles exactly the digits this feature exists to read.
            request.usesLanguageCorrection = false

            // The languages the app speaks. Italian matters here — it changes
            // how the recogniser reads accented characters on a receipt.
            request.recognitionLanguages = ["en-US", "it-IT", "ar-SA"]

            // Receipt type is small and thermal-printed; without this, short
            // numeric fragments get discarded as noise.
            request.minimumTextHeight = 0.008

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Vision returns fragments with positions, not lines. An item and its
    /// price sit at the same height on a receipt but at opposite edges, so they
    /// arrive as two observations and have to be put back together — otherwise
    /// "TOTALE" and "63,80" are never on the same line and no keyword ever
    /// matches its amount.
    private static func group(_ observations: [VNRecognizedTextObservation]) -> [String] {
        struct Fragment {
            let text: String
            let midY: CGFloat
            let minX: CGFloat
        }

        let fragments: [Fragment] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return Fragment(text: candidate.string, midY: box.midY, minX: box.minX)
        }

        // Vision's origin is bottom-left, so descending midY is top-to-bottom.
        let sorted = fragments.sorted { $0.midY > $1.midY }

        var lines: [[Fragment]] = []
        // Roughly one line of receipt type. Too tight and a price splits from
        // its label; too loose and two rows merge into one.
        let tolerance: CGFloat = 0.012

        for fragment in sorted {
            if let index = lines.indices.last,
               let reference = lines[index].first,
               abs(reference.midY - fragment.midY) < tolerance {
                lines[index].append(fragment)
            } else {
                lines.append([fragment])
            }
        }

        return lines.map { line in
            line.sorted { $0.minX < $1.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}
