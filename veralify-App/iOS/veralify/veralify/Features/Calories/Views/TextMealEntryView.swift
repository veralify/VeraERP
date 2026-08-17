import SwiftUI

/// Sheet for Cal AI's "describe your meal" text-entry flow.
struct TextMealEntryView: View {
    let onSubmit: (String) -> Void

    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Describe what you ate, and Veralify AI will estimate the calories and macros.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("e.g. Grilled chicken with rice and salad", text: $text, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(AppTheme.composerFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($isFocused)

                Spacer()
            }
            .padding()
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analyze") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                        onSubmit(trimmed)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
