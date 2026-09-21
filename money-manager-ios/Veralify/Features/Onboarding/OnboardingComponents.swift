import SwiftUI

/// Adds a Done bar above the keyboard and lets a scroll dismiss it.
///
/// Number pads have no return key, so a form of amount fields is otherwise a
/// trap: the keyboard covers the primary action and nothing dismisses it.
///
/// Takes no focus binding. It used to take one shared `FocusState<Bool>` per
/// screen, which every field on that screen then bound to — so a form's fields
/// had no separate focus identity and could steal it from each other. Resigning
/// first responder dismisses whichever field is actually editing, and leaves
/// each field owning its own focus.
struct DismissibleKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { KeyboardDismiss.resign() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                }
            }
    }
}

enum KeyboardDismiss {
    @MainActor
    static func resign() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}

extension View {
    func dismissibleKeyboard() -> some View { modifier(DismissibleKeyboard()) }
}

/// Labelled text field in the app's dark style.
///
/// Owns its focus. Sharing one `FocusState` across a form's fields gave them no
/// separate identity, so focus could land on the wrong one — typing meant for
/// the second field went into the first.
struct FieldRow: View {
    let label: LocalizedStringKey
    var placeholder: LocalizedStringKey = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done

    @FocusState private var isFocused: Bool

    /// Amount fields arrive prefilled and the cursor lands at the end, so typing
    /// a new figure appended to the old one — a €105 minimum became
    /// €10,520,708.15. Selecting the text on focus makes the first keystroke
    /// replace it, the way an amount field is expected to behave.
    private var selectsOnFocus: Bool { keyboard == .decimalPad || keyboard == .numberPad }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .submitLabel(submitLabel)
                    .focused($isFocused)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)

                // A visible way to empty the field. Number pads have no clear
                // key, so correcting a prefilled amount otherwise meant holding
                // backspace.
                if isFocused && !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .accessibilityLabel("Clear")
                }
            }
            .animation(.smooth(duration: 0.15), value: isFocused)
            .onChange(of: isFocused) { _, focused in
                guard focused, selectsOnFocus, !text.isEmpty else { return }
                // A turn later, so the field is first responder and SwiftUI has
                // finished its own update — selecting during the focus change
                // itself gets overwritten.
                Task { @MainActor in
                    (UIResponder.currentFirstResponder as? UITextField)?.selectAll(nil)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inner)
                    .strokeBorder(isFocused ? Theme.lime.opacity(0.6) : Theme.stroke, lineWidth: 1)
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
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("Delete \(title)"))
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
        .buttonStyle(.pressable)
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
        .buttonStyle(.pressable)
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
        .accessibilityLabel(Text("Step \(current + 1) of \(total)"))
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
            // Unconditional now: every onboarding step has number-pad fields,
            // which have no return key, so the Done bar is the only way off the
            // keyboard.
            .dismissibleKeyboard()

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


/// Applies a focus binding only when one was supplied.



extension UIResponder {
    private static weak var activeResponder: UIResponder?

    /// The responder currently holding focus.
    ///
    /// UIKit does not expose this, so it is found the documented way: send an
    /// action to `nil` and let the responder chain deliver it to whoever is
    /// first responder.
    @MainActor
    static var currentFirstResponder: UIResponder? {
        activeResponder = nil
        UIApplication.shared.sendAction(
            #selector(captureFirstResponder), to: nil, from: nil, for: nil
        )
        return activeResponder
    }

    @objc private func captureFirstResponder(_ sender: Any?) {
        UIResponder.activeResponder = self
    }
}
