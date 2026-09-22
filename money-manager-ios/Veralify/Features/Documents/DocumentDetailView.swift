import SwiftUI
import SwiftData
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

/// One document, opened: the card, its photo, and every field a tap from the
/// clipboard.
struct DocumentDetailView: View {
    @Bindable var document: StoredDocument
    let notifications: NotificationManager

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingPhoto = false
    @State private var isConfirmingPhotoRemoval = false
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    DocumentCardFace(document: document)
                    photoSection
                    fieldsSection
                    remindersSummary
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if let toast {
                CopyToast(text: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: toast)
        .navigationTitle(document.documentType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.lime)
            }
        }
        .sheet(isPresented: $isEditing) {
            DocumentEditSheet(document: document, notifications: notifications)
                .presentationBackground(Theme.background)
        }
        .fullScreenCover(isPresented: $isShowingPhoto) {
            if let data = document.photoData, let image = UIImage(data: data) {
                PhotoViewer(image: image) { isShowingPhoto = false }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await attach(item) }
        }
        .confirmationDialog(
            "Remove this photo?",
            isPresented: $isConfirmingPhotoRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove photo", role: .destructive) {
                document.photoData = nil
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The document's details stay. Only the image is deleted.")
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoSection: some View {
        if let data = document.photoData, let image = UIImage(data: data) {
            VStack(spacing: 10) {
                Button { isShowingPhoto = true } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("View the document photo full screen")

                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        isConfirmingPhotoRemoval = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, 4)
            }
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.lime)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a photo")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Kept on this device, behind your passcode")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.pressable)
        }
    }

    private func attach(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        // Downscaled before storing: a modern camera roll image is several
        // megabytes, and a document only has to be readable.
        let stored = Self.downscaledJPEG(data) ?? data
        document.photoData = stored
        try? context.save()
        photoItem = nil
    }

    /// Longest edge capped at 2000px, which keeps the smallest print on a
    /// passport legible while cutting a 12MP photo to a few hundred kilobytes.
    ///
    /// Done through ImageIO rather than `UIImage`: it resizes while decoding,
    /// so a 6000×4500 photo never becomes a 100MB bitmap in memory, and it
    /// re-encodes from the pixels alone. Nothing from the original's metadata
    /// survives — a photo of a passport should not also record where the
    /// passport was photographed.
    static func downscaledJPEG(_ data: Data, maxEdge: Int = 2000) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes in the EXIF orientation, which is the only part of the
            // metadata worth keeping — without it a photo taken sideways is
            // stored sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            TapToCopyChip(
                label: "Number",
                value: document.documentNumber,
                needsConfirming: !document.isVerified && !document.documentNumber.isEmpty,
                onCopy: show
            )
            TapToCopyChip(label: "Name", value: document.holderName, onCopy: show)

            if let dob = document.dateOfBirth {
                TapToCopyChip(
                    label: "Date of birth",
                    value: dob.formatted(.dateTime.day().month(.abbreviated).year()),
                    onCopy: show
                )
            }
            if let expiry = document.expirationDate {
                TapToCopyChip(
                    label: "Expires",
                    value: expiry.formatted(.dateTime.day().month(.abbreviated).year()),
                    onCopy: show
                )
            }
            if !document.nationality.isEmpty {
                TapToCopyChip(label: "Nationality", value: document.nationality, onCopy: show)
            }
            if !document.issuingCountry.isEmpty {
                TapToCopyChip(label: "Issued by", value: document.issuingCountry, onCopy: show)
            }
        }
    }

    @ViewBuilder
    private var remindersSummary: some View {
        if document.expirationDate != nil, !document.reminderDays.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.lime)
                Text("Reminders \(document.reminderDays.map { NotificationManager.label(forDays: $0) }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
    }

    private func show(_ value: String) {
        toast = value
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            toast = nil
        }
    }
}

/// The photo, full screen and zoomable.
///
/// Zoom and pan are the whole point of this screen: the reason to keep a photo
/// of a document is to read something small off it later — a number, a stamp, a
/// date — so a pinch has to hold where it was left and the image has to move
/// under the finger.
private struct PhotoViewer: View {
    let image: UIImage
    let onClose: () -> Void

    /// Where the last gesture left things, and what the one in progress adds.
    @State private var scale: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var drag: CGSize = .zero

    private static let maxScale: CGFloat = 5

    private var currentScale: CGFloat { min(max(scale * pinch, 1), Self.maxScale) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(currentScale)
                .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                .gesture(magnify)
                .simultaneousGesture(pan)
                .onTapGesture(count: 2) { toggleZoom() }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.55), in: .circle)
            }
            .padding(20)
            .accessibilityLabel("Close")
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { pinch = $0.magnification }
            .onEnded { _ in
                scale = currentScale
                pinch = 1
                if scale <= 1.02 { reset() }
            }
    }

    /// Only when zoomed in — at 1× the image fills the screen, so a drag would
    /// slide it off for no reason.
    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard currentScale > 1 else { return }
                drag = value.translation
            }
            .onEnded { _ in
                offset.width += drag.width
                offset.height += drag.height
                drag = .zero
            }
    }

    private func toggleZoom() {
        withAnimation(.snappy(duration: 0.3)) {
            if scale > 1 {
                reset()
            } else {
                scale = 2.5
            }
        }
    }

    private func reset() {
        scale = 1
        pinch = 1
        offset = .zero
        drag = .zero
    }
}
