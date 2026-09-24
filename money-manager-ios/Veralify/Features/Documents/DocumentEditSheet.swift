import SwiftUI
import SwiftData

/// Confirm a scan before it is saved.
///
/// Always shown, never skipped. OCR on a passport is good but not certain, and
/// the check digits only cover the machine-readable zone — everything here is
/// editable because everything here can be wrong.
struct DocumentReviewSheet: View {
    let scanned: ScannedDocument
    let notifications: NotificationManager
    let onSave: (StoredDocument) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var documentType: DocumentType
    @State private var holderName: String
    @State private var documentNumber: String
    @State private var dateOfBirth: Date
    @State private var hasDateOfBirth: Bool
    @State private var expirationDate: Date
    @State private var hasExpiry: Bool
    @State private var nationality: String
    @State private var reminderDays: Set<Int>

    init(scanned: ScannedDocument, notifications: NotificationManager, onSave: @escaping (StoredDocument) -> Void) {
        self.scanned = scanned
        self.notifications = notifications
        self.onSave = onSave

        _documentType = State(initialValue: scanned.documentType)
        _holderName = State(initialValue: scanned.holderName)
        _documentNumber = State(initialValue: scanned.documentNumber)
        _dateOfBirth = State(initialValue: scanned.dateOfBirth ?? Date())
        _hasDateOfBirth = State(initialValue: scanned.dateOfBirth != nil)
        // A document with no expiry read is far more likely to have one that was
        // missed than not to have one, so the toggle starts on.
        _expirationDate = State(initialValue: scanned.expirationDate ?? Date())
        _hasExpiry = State(initialValue: true)
        _nationality = State(initialValue: scanned.nationality)
        _reminderDays = State(initialValue: [90, 30])
    }

    var body: some View {
        DocumentForm(
            title: scanned.hasMRZ ? "Check the details" : "New document",
            verification: verificationBanner,
            documentType: $documentType,
            holderName: $holderName,
            documentNumber: $documentNumber,
            dateOfBirth: $dateOfBirth,
            hasDateOfBirth: $hasDateOfBirth,
            expirationDate: $expirationDate,
            hasExpiry: $hasExpiry,
            nationality: $nationality,
            reminderDays: $reminderDays,
            notifications: notifications,
            saveTitle: "Save document",
            onSave: save,
            onDelete: nil
        )
    }

    private var verificationBanner: DocumentForm.Verification? {
        guard scanned.hasMRZ else { return nil }
        return scanned.isVerified ? .verified : .checkDigitFailed
    }

    private func save() {
        onSave(
            StoredDocument(
                documentType: documentType,
                holderName: holderName.trimmingCharacters(in: .whitespaces),
                documentNumber: documentNumber.trimmingCharacters(in: .whitespaces),
                expirationDate: hasExpiry ? expirationDate : nil,
                dateOfBirth: hasDateOfBirth ? dateOfBirth : nil,
                nationality: nationality.trimmingCharacters(in: .whitespaces),
                issuingCountry: scanned.issuingCountry,
                reminderDays: reminderDays.sorted(by: >),
                isVerified: scanned.isVerified
            )
        )
        dismiss()
    }
}

/// Edit a document already saved.
struct DocumentEditSheet: View {
    @Bindable var document: StoredDocument
    let notifications: NotificationManager

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dateOfBirth: Date
    @State private var hasDateOfBirth: Bool
    @State private var expirationDate: Date
    @State private var hasExpiry: Bool
    @State private var reminderDays: Set<Int>

    init(document: StoredDocument, notifications: NotificationManager) {
        self.document = document
        self.notifications = notifications
        _dateOfBirth = State(initialValue: document.dateOfBirth ?? Date())
        _hasDateOfBirth = State(initialValue: document.dateOfBirth != nil)
        _expirationDate = State(initialValue: document.expirationDate ?? Date())
        _hasExpiry = State(initialValue: document.expirationDate != nil)
        _reminderDays = State(initialValue: Set(document.reminderDays))
    }

    var body: some View {
        DocumentForm(
            title: "Edit document",
            verification: nil,
            documentType: $document.documentType,
            holderName: $document.holderName,
            documentNumber: $document.documentNumber,
            dateOfBirth: $dateOfBirth,
            hasDateOfBirth: $hasDateOfBirth,
            expirationDate: $expirationDate,
            hasExpiry: $hasExpiry,
            nationality: $document.nationality,
            reminderDays: $reminderDays,
            notifications: notifications,
            saveTitle: "Save changes",
            onSave: save,
            onDelete: delete
        )
    }

    private func save() {
        document.dateOfBirth = hasDateOfBirth ? dateOfBirth : nil
        document.expirationDate = hasExpiry ? expirationDate : nil
        document.reminderDays = reminderDays.sorted(by: >)
        // An edited field may have corrected what the check digit flagged, so
        // the warning clears once a person has been through it.
        document.isVerified = true
        try? context.save()

        let saved = document
        Task { await notifications.reschedule(for: saved) }
        dismiss()
    }

    private func delete() {
        notifications.cancel(for: document.id)
        context.delete(document)
        try? context.save()
        dismiss()
    }
}

// MARK: - Shared form

/// The fields, shared by the review and edit sheets so the two cannot drift.
struct DocumentForm: View {
    enum Verification { case verified, checkDigitFailed }

    let title: LocalizedStringKey
    let verification: Verification?

    @Binding var documentType: DocumentType
    @Binding var holderName: String
    @Binding var documentNumber: String
    @Binding var dateOfBirth: Date
    @Binding var hasDateOfBirth: Bool
    @Binding var expirationDate: Date
    @Binding var hasExpiry: Bool
    @Binding var nationality: String
    @Binding var reminderDays: Set<Int>

    let notifications: NotificationManager
    let saveTitle: LocalizedStringKey
    let onSave: () -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    private var canSave: Bool {
        !documentNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let verification { verificationBanner(verification) }
                        typePicker
                        detailsCard
                        remindersCard
                        PrimaryButton(title: saveTitle, enabled: canSave, action: onSave)
                        if onDelete != nil {
                            Button(role: .destructive) { isConfirmingDelete = true } label: {
                                Text("Delete document")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.red)
                                    // A full-width 44pt target: the bare text
                                    // was a sliver under the save button.
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(.rect)
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .confirmationDialog("Delete this document?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onDelete?() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its details and any reminders will be removed from this device.")
            }
        }
    }

    private func verificationBanner(_ verification: Verification) -> some View {
        switch verification {
        case .verified:
            AlertBanner(
                icon: "checkmark.seal.fill",
                title: "Read and verified",
                message: "The document's own check digits confirm these were read correctly. Worth a glance anyway.",
                accent: Theme.green
            )
        case .checkDigitFailed:
            AlertBanner(
                icon: "exclamationmark.triangle.fill",
                title: "One field didn't add up",
                message: "A check digit in the machine-readable zone disagrees, so something was misread. Compare it against the document before saving.",
                accent: Theme.yellow
            )
        }
    }

    private var typePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(DocumentType.allCases) { option in
                    Button { documentType = option } label: {
                        Label(option.title, systemImage: option.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(documentType == option ? Theme.onAccent : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(documentType == option ? Theme.lime : Theme.surfaceElevated, in: .capsule)
                            // The capsule stays 34pt; the tappable area around
                            // it reaches 44.
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private var detailsCard: some View {
        VStack(spacing: 14) {
            FieldRow(label: "Document number", placeholder: "AB1234567", text: $documentNumber)
            FieldRow(label: "Name", placeholder: "As printed", text: $holderName)
            FieldRow(label: "Nationality", placeholder: "ITA", text: $nationality)

            // Each date sits tighter to the toggle that reveals it than to the
            // next field, so the pair reads as one control.
            VStack(spacing: 10) {
                Toggle(isOn: $hasDateOfBirth) {
                    Text("Date of birth")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.lime)
                if hasDateOfBirth {
                    DateField(label: "Born", date: $dateOfBirth)
                }
            }

            VStack(spacing: 10) {
                Toggle(isOn: $hasExpiry) {
                    Text("Has an expiry date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.lime)
                if hasExpiry {
                    DateField(label: "Expires", date: $expirationDate)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    @ViewBuilder
    private var remindersCard: some View {
        if hasExpiry {
            VStack(alignment: .leading, spacing: 12) {
                Text("Remind me")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                // Rows butt together at 44pt each rather than being spaced
                // apart, so the target is full height without the list
                // spreading out.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(NotificationManager.offeredDays, id: \.self) { days in
                        Button {
                            if reminderDays.contains(days) { reminderDays.remove(days) }
                            else { reminderDays.insert(days) }
                            Task { await requestPermissionIfNeeded() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: reminderDays.contains(days) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(reminderDays.contains(days) ? Theme.lime : Theme.textTertiary)
                                Text(NotificationManager.label(forDays: days))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 7)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                    }
                }

                if notifications.permission == .denied {
                    Text("Notifications are off for Veralify, so these won't arrive until you turn them on in Settings.")
                        .font(.caption)
                        .foregroundStyle(Theme.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
    }

    /// Asked at the moment the user picks a reminder, not on first launch — the
    /// prompt makes sense when it is obvious what it is for.
    private func requestPermissionIfNeeded() async {
        guard !reminderDays.isEmpty, notifications.permission == .unknown else { return }
        await notifications.requestPermission()
    }
}
