import SwiftUI
import UIKit

/// A field that copies itself when tapped.
///
/// Copying is the whole point of a document vault: nobody reads a passport
/// number off a screen and retypes it into a booking form. The tap needs to be
/// unmistakable, so it lands three ways at once — the chip flashes, the phone
/// taps back, and a toast confirms what went to the clipboard.
struct TapToCopyChip: View {
    let label: LocalizedStringKey
    let value: String
    /// Set when a check digit disagreed with the printed value, so the field
    /// shows as unconfirmed rather than silently wrong.
    var needsConfirming = false
    let onCopy: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlashing = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCopy(value)

            withAnimation(reduceMotion ? .none : .snappy(duration: 0.14)) { isFlashing = true }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(reduceMotion ? .none : .smooth(duration: 0.3)) { isFlashing = false }
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    if needsConfirming {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.yellow)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }

                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(value.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            // Fills the height it is offered, so two chips side by side in a
            // grid row match when only one value wraps to a second line.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                isFlashing ? Theme.lime.opacity(0.22) : Theme.surface,
                in: .rect(cornerRadius: Theme.Radius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isFlashing ? Theme.lime : (needsConfirming ? Theme.yellow.opacity(0.5) : .clear),
                        lineWidth: 1
                    )
            )
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(value.isEmpty)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint("Double tap to copy")
    }
}

/// The "Copied" confirmation.
///
/// Sits over the content rather than pushing it, so tapping several fields in a
/// row does not make the page jump under the user's thumb.
struct CopyToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.footnote.weight(.bold))
            Text("Copied \(text)")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Theme.onAccent)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Theme.lime, in: .capsule)
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        // Keeps the screen gutter when a long value fills the capsule, rather
        // than letting it run edge to edge before truncating.
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }
}
