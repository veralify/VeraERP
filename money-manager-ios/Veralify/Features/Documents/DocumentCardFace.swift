import SwiftUI

/// One document as a card, coloured like the real thing.
///
/// The face deliberately carries no number and no date of birth. A wallet is
/// something you open in public — the identifying detail belongs one tap in,
/// not on a screen someone can read over your shoulder.
struct DocumentCardFace: View {
    let document: StoredDocument
    /// A collapsed card shows only its top strip, the way cards sit in a real
    /// wallet with the ones behind peeking out.
    var isCollapsed = false

    private var type: DocumentType { document.documentType }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !isCollapsed {
                Spacer(minLength: 0)
                footer
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isCollapsed ? Self.collapsedHeight : Self.height, alignment: .top)
        .background(cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }

    static let height: CGFloat = 188
    static let collapsedHeight: CGFloat = 86

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.title.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(type.cardInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if !document.holderName.isEmpty {
                    Text(document.holderName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(type.cardInk.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(type.cardInk.opacity(0.55))
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            expiryBadge
            Spacer(minLength: 8)

            if document.photoData != nil {
                Image(systemName: "photo.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(type.cardInk.opacity(0.5))
            }

            Text(document.photoData != nil ? "PHOTO" : "VERALIFY")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(type.cardInk.opacity(0.35))
        }
    }

    @ViewBuilder
    private var expiryBadge: some View {
        if let days = document.daysUntilExpiry {
            let label: LocalizedStringKey = document.hasExpired
                ? "Expired"
                : (days == 0 ? "Expires today" : "Expires in \(days) days")
            let tint: Color = document.hasExpired
                ? Theme.red
                : (document.expiresSoon ? Theme.yellow : type.cardInk.opacity(0.14))
            let ink: Color = document.hasExpired || document.expiresSoon
                ? Theme.onAccent
                : type.cardInk

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tint, in: .capsule)
        }
    }

    /// The guilloché hatching real documents carry, suggested rather than
    /// imitated — enough texture that a flat colour does not read as a
    /// placeholder.
    private var cardSurface: some View {
        ZStack(alignment: .topTrailing) {
            type.cardColor

            Canvas { context, size in
                let ink = type.cardInk.opacity(0.07)
                var path = Path()
                var x = size.width * 0.45
                while x < size.width + size.height {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x - size.height, y: size.height))
                    x += 7
                }
                context.stroke(path, with: .color(ink), lineWidth: 1.2)
            }
            .allowsHitTesting(false)
        }
    }
}
