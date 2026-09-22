import Foundation
import SwiftData
import SwiftUI
import VeralifyCore

/// An identity document the user has scanned.
///
/// This is the most sensitive data the app holds — a passport number, a date of
/// birth and a full name together are enough to open accounts in someone's
/// name. It never leaves the device, and the store is protected so it cannot be
/// read while the phone is locked. See `VeralifyApp` for that configuration.
///
/// The scanned image is kept only when the user asks for it. A photograph of a
/// passport is far more dangerous than its fields — it can be forwarded, and it
/// carries the photo and signature too — so it is opt-in, stored outside the
/// database, and covered by the same protection as everything else.
@Model
final class StoredDocument {
    @Attribute(.unique) var id: UUID
    var documentTypeRaw: String
    var holderName: String
    var documentNumber: String
    var expirationDate: Date?
    var dateOfBirth: Date?
    var nationality: String
    var issuingCountry: String
    /// Anything the parser found that has no column of its own, so a document
    /// type nobody anticipated still keeps its fields.
    var extraFields: [String: String]
    /// Days before expiry to warn. Empty means no reminders.
    var reminderDays: [Int]
    /// False when a check digit did not match, so the UI can keep asking the
    /// user to confirm rather than quietly trusting a misread.
    var isVerified: Bool
    var createdAt: Date

    /// The document photo, when the user chose to keep one.
    ///
    /// `.externalStorage` writes the bytes to a file beside the database rather
    /// than inlining a multi-megabyte blob into every row fetch. Those files sit
    /// in the same protected directory — see `VeralifyApp.protectStore`.
    @Attribute(.externalStorage) var photoData: Data?

    init(
        id: UUID = UUID(),
        documentType: DocumentType,
        holderName: String,
        documentNumber: String,
        expirationDate: Date? = nil,
        dateOfBirth: Date? = nil,
        nationality: String = "",
        issuingCountry: String = "",
        extraFields: [String: String] = [:],
        reminderDays: [Int] = [90, 30],
        isVerified: Bool = false,
        createdAt: Date = .now,
        photoData: Data? = nil
    ) {
        self.id = id
        self.documentTypeRaw = documentType.rawValue
        self.holderName = holderName
        self.documentNumber = documentNumber
        self.expirationDate = expirationDate
        self.dateOfBirth = dateOfBirth
        self.nationality = nationality
        self.issuingCountry = issuingCountry
        self.extraFields = extraFields
        self.reminderDays = reminderDays
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.photoData = photoData
    }

    var documentType: DocumentType {
        get { DocumentType(rawValue: documentTypeRaw) ?? .other }
        set { documentTypeRaw = newValue.rawValue }
    }

    /// Days until it expires. Negative once it has.
    var daysUntilExpiry: Int? {
        guard let expirationDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: expirationDate)
        ).day
    }

    var hasExpired: Bool { (daysUntilExpiry ?? 1) < 0 }
    /// Inside the window where renewing takes long enough to start now.
    var expiresSoon: Bool {
        guard let days = daysUntilExpiry else { return false }
        return days >= 0 && days <= 180
    }
}

extension DocumentType {
    /// The colour the real document is, so a wallet of them is readable at a
    /// glance the way a physical one is. EU driving licences are pink, Italian
    /// health cards are pale blue, passports are burgundy.
    var cardColor: Color {
        switch self {
        case .passport:        Color(red: 0.44, green: 0.13, blue: 0.18)
        case .idCard:          Color(red: 0.62, green: 0.83, blue: 0.91)
        case .drivingLicence:  Color(red: 0.96, green: 0.80, blue: 0.85)
        case .residencePermit: Color(red: 0.72, green: 0.87, blue: 0.74)
        case .other:           Theme.surfaceElevated
        }
    }

    /// Readable on `cardColor`, which runs from burgundy to pale pink.
    var cardInk: Color {
        switch self {
        case .passport: .white
        case .other:    Theme.textPrimary
        default:        Color(red: 0.15, green: 0.10, blue: 0.16)
        }
    }
}

enum DocumentType: String, CaseIterable, Identifiable, Hashable {
    case passport, idCard, drivingLicence, residencePermit, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .passport:        String(localized: "Passport")
        case .idCard:          String(localized: "ID card")
        case .drivingLicence:  String(localized: "Driving licence")
        case .residencePermit: String(localized: "Residence permit")
        case .other:           String(localized: "Document")
        }
    }

    var icon: String {
        switch self {
        case .passport:        "book.pages.fill"
        case .idCard:          "person.text.rectangle.fill"
        case .drivingLicence:  "car.fill"
        case .residencePermit: "doc.text.fill"
        case .other:           "doc.fill"
        }
    }

    /// What an MRZ document code maps to.
    static func from(mrzCode: String) -> DocumentType {
        switch mrzCode.uppercased().first {
        case "P": .passport
        case "I", "A", "C": .idCard
        default: .other
        }
    }
}
