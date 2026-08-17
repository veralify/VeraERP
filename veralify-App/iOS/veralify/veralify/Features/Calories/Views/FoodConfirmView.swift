import SwiftUI

/// Review/edit screen shown after any logging flow (photo, barcode, or
/// text) — Cal AI's "Fix Results" step — before the entry is saved.
struct FoodConfirmView: View {
    @Binding var pending: PendingFoodConfirmation
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let data = pending.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    nameCard
                    caloriesCard
                    macrosCard

                    if !pending.detectedIngredients.isEmpty {
                        ingredientsCard
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Confirm Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log It") { onConfirm() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Meal name", text: $pending.name)
                .font(.headline)
            if let brand = pending.brand, !brand.isEmpty {
                Text(brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Serving", text: $pending.servingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .premiumCard()
    }

    private var caloriesCard: some View {
        HStack {
            Label("Calories", systemImage: "flame.fill")
                .foregroundStyle(AppTheme.accent)
            Spacer()
            Stepper(value: $pending.calories, in: 0...5000, step: 10) {
                Text("\(pending.calories) cal")
                    .font(.headline)
            }
        }
        .premiumCard()
    }

    private var macrosCard: some View {
        VStack(spacing: 12) {
            macroStepper(title: "Protein", value: $pending.proteinGrams, color: .red)
            Divider()
            macroStepper(title: "Carbs", value: $pending.carbGrams, color: .orange)
            Divider()
            macroStepper(title: "Fat", value: $pending.fatGrams, color: .blue)
        }
        .premiumCard()
    }

    private func macroStepper(title: String, value: Binding<Double>, color: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(color)
            Spacer()
            Stepper(value: value, in: 0...500, step: 1) {
                Text("\(Int(value.wrappedValue))g")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Ingredients")
                .font(.subheadline.weight(.semibold))
            ForEach(pending.detectedIngredients, id: \.self) { ingredient in
                Text("• \(ingredient)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }
}
