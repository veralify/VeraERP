import SwiftUI
import Vision
import VisionKit
import UIKit
import VeralifyCore

/// What a scan produced, before it is saved.
struct ScannedDocument {
    var documentType: DocumentType = .other
    var holderName = ""
    var documentNumber = ""
    var dateOfBirth: Date?
    var expirationDate: Date?
    var nationality = ""
    var issuingCountry = ""
    /// False when an MRZ check digit disagreed. Nil-ish for documents with no
    /// machine-readable zone, where nothing can be verified either way.
    var isVerified = false
    var hasMRZ = false
}

/// The camera, wrapped for SwiftUI, reading identity documents.
///
/// Reuses the receipt scanner's document camera: edge detection and perspective
/// correction matter as much for a passport photographed on a table as for a
/// receipt.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onResult: @MainActor @Sendable (Result<ScannedDocument, Error>) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    /// Not `@MainActor`: the delegate protocol is not isolated, so each callback
    /// hops back explicitly instead.
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onResult: @MainActor @Sendable (Result<ScannedDocument, Error>) -> Void

        init(onResult: @escaping @MainActor @Sendable (Result<ScannedDocument, Error>) -> Void) {
            self.onResult = onResult
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let deliver = onResult
            guard scan.pageCount > 0, let page = scan.imageOfPage(at: 0).cgImage else {
                Task { @MainActor in deliver(.failure(ReceiptScanError.noImage)) }
                return
            }

            Task {
                do {
                    let lines = try await ReceiptTextRecognizer.lines(in: page)
                    let parsed = DocumentFieldParser.parse(lines: lines)
                    await MainActor.run { deliver(.success(parsed)) }
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

/// Turns recognised text into document fields.
///
/// Two routes, in order of trust:
///
/// 1. **The machine-readable zone.** Every field carries a check digit, so a
///    passport or modern ID card can be read *and verified*. This is why the
///    MRZ is tried first and why nothing else is consulted when it succeeds.
/// 2. **Labelled text**, for documents with no zone — most driving licences.
///    Best-effort, never marked verified.
enum DocumentFieldParser {

    static func parse(lines: [String]) -> ScannedDocument {
        if let mrz = MRZParser.parse(lines: lines) {
            return fromMRZ(mrz)
        }
        return fromLabels(lines)
    }

    private static func fromMRZ(_ mrz: MRZDocument) -> ScannedDocument {
        let calendar = Calendar(identifier: .gregorian)

        return ScannedDocument(
            documentType: DocumentType.from(mrzCode: mrz.documentCode),
            holderName: mrz.fullName,
            documentNumber: mrz.documentNumber,
            dateOfBirth: calendar.date(from: mrz.dateOfBirth),
            expirationDate: calendar.date(from: mrz.expiryDate),
            nationality: mrz.nationality,
            issuingCountry: mrz.issuingCountry,
            isVerified: mrz.isFullyVerified,
            hasMRZ: true
        )
    }

    /// Keyword matching for documents without a zone.
    ///
    /// Deliberately modest: it fills what it can recognise and leaves the rest
    /// to the user. Guessing a passport number from unlabelled text and being
    /// wrong is worse than leaving the field empty.
    private static func fromLabels(_ lines: [String]) -> ScannedDocument {
        var result = ScannedDocument()

        let joined = lines.joined(separator: " ").lowercased()
        if joined.contains("passport") || joined.contains("passaporto") {
            result.documentType = .passport
        } else if joined.contains("driving") || joined.contains("driver")
                    || joined.contains("patente") || joined.contains("guida") {
            result.documentType = .drivingLicence
        } else if joined.contains("identity") || joined.contains("identità")
                    || joined.contains("identita") {
            result.documentType = .idCard
        }

        for (index, line) in lines.enumerated() {
            let lowered = line.lowercased()

            if result.documentNumber.isEmpty,
               lowered.contains("no.") || lowered.contains("n.")
                || lowered.contains("number") || lowered.contains("numero") {
                result.documentNumber = documentNumberCandidate(in: line) ?? ""
            }

            if result.holderName.isEmpty,
               lowered.contains("surname") || lowered.contains("cognome")
                || lowered.contains("name") || lowered.contains("nome") {
                // The value is usually the next line, not this one — the label
                // sits on its own row on almost every ID.
                if index + 1 < lines.count {
                    let candidate = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if candidate.count > 2, candidate.rangeOfCharacter(from: .decimalDigits) == nil {
                        result.holderName = candidate
                    }
                }
            }

            if result.expirationDate == nil,
               lowered.contains("expir") || lowered.contains("scadenza")
                || lowered.contains("valid until") || lowered.contains("valido fino") {
                result.expirationDate = date(in: line) ?? nextLineDate(lines, after: index)
            }

            if result.dateOfBirth == nil,
               lowered.contains("birth") || lowered.contains("nascita") || lowered.contains("dob") {
                result.dateOfBirth = date(in: line) ?? nextLineDate(lines, after: index)
            }
        }

        return result
    }

    private static func nextLineDate(_ lines: [String], after index: Int) -> Date? {
        guard index + 1 < lines.count else { return nil }
        return date(in: lines[index + 1])
    }

    /// A run of 6–12 characters that looks like a document number: letters and
    /// digits, at least one of each or all digits.
    private static func documentNumberCandidate(in line: String) -> String? {
        let tokens = line.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return tokens
            .map(String.init)
            .first { token in
                (6...12).contains(token.count)
                    && token.rangeOfCharacter(from: .decimalDigits) != nil
                    && token.uppercased() == token
            }
    }

    /// Dates as printed on documents, in the orders they actually appear.
    ///
    /// Day-first is listed before month-first because everywhere that issues a
    /// document in these formats writes the day first; a US licence prints a
    /// month name instead, which the third format catches.
    private static func date(in line: String) -> Date? {
        let patterns = ["dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yyyy", "dd MMM yyyy", "yyyy-MM-dd"]

        let tokens = line.split(whereSeparator: { $0 == " " })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ":,")) }

        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern

            for token in tokens {
                if let date = formatter.date(from: token) { return date }
            }
            // "12 MAR 2029" is three tokens, so try the tail of the line too.
            if tokens.count >= 3 {
                let tail = tokens.suffix(3).joined(separator: " ")
                if let date = formatter.date(from: tail) { return date }
            }
        }
        return nil
    }
}
