import SwiftUI

/// Labelled text field in the app's dark style.
struct FieldRow: View {
    let label: LocalizedStringKey
    var placeholder: LocalizedStringKey = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        }
    }
}

/// A committed entry, with a way to take it back out.
struct EntryChipRow: View {
    let title: String
    let detail: String
    let accent: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.surfaceElevated, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("حذف \(title)")
        }
        .padding(.vertical, 10)
    }
}

/// Primary action in the onboarding flow.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Theme.lime.readableForeground : Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                // Fading the lime to 40% over black produces a murky olive that
                // reads as broken rather than disabled, so the disabled state
                // drops to a neutral surface instead.
                .background(enabled ? Theme.lime : Theme.surfaceElevated, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Step progress. Lime marks completed steps, so the flow always shows how much
/// is left — the reference's progress bar idea applied to a wizard.
struct StepProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.lime : Theme.surfaceElevated)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("الخطوة \(current + 1) من \(total)")
    }
}

/// Shared scaffold: title, supporting copy, content, then the action row.
struct OnboardingScaffold<Content: View, Actions: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Theme.background)
        }
    }
}
