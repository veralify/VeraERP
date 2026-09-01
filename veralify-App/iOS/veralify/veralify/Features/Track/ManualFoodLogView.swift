import SwiftUI

struct ManualFoodLogView: View {
    @ObservedObject var viewModel: TrackViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VeraTokens.Spacing._4) {
                    Picker("Meal", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Meal type")

                    searchField
                    searchResults
                    if let food = viewModel.selectedFood { portionPicker(food) }
                }
                .padding(VeraTokens.Spacing._4)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(viewModel.editingItem == nil ? "Log Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.editingItem = nil; viewModel.resetManualForm(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving…" : "Save") {
                        Task { await viewModel.saveSelectedFood(); if viewModel.errorMessage == nil { dismiss() } }
                    }
                    .disabled(viewModel.selectedFood == nil || viewModel.isSaving)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: VeraTokens.Spacing._2) {
            Image(systemName: "magnifyingglass").foregroundStyle(VeraTokens.Colors.fgMuted)
            TextField("Search foods", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search() } }
            Button("Search") { Task { await viewModel.search() } }
                .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
        }
        .padding(VeraTokens.Spacing._3)
        .background(RoundedRectangle(cornerRadius: VeraTokens.Radii.md).fill(VeraTokens.Colors.surface))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Food search")
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty {
            ShellEmptyStateView(title: "Search internal foods", message: "Results come from the foods and food_servings tables.", systemImage: "leaf.fill", ctaTitle: "Type a food", ctaSystemImage: "keyboard")
                .frame(minHeight: 260)
        } else if viewModel.searchResults.isEmpty {
            Text("No foods found. Try a simpler search term.")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
                .premiumCard()
        } else {
            VStack(spacing: VeraTokens.Spacing._2) {
                ForEach(viewModel.searchResults) { food in
                    Button { Task { await viewModel.select(food: food) } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name).font(.headline).foregroundStyle(VeraTokens.Colors.fg)
                                Text("\(food.brand ?? food.source) · \(Int(food.calories.rounded())) kcal / \(Int(food.servingSize.rounded())) \(food.servingUnit)")
                                    .font(.caption)
                                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                            }
                            Spacer()
                            if viewModel.selectedFood?.id == food.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(VeraTokens.Colors.primary) }
                        }
                        .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
                        .premiumCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func portionPicker(_ food: FoodSearchResult) -> some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Text("Portion").font(.headline)
            Picker("Serving", selection: $viewModel.selectedServingGrams) {
                Text("Default — \(Int(food.servingSize.rounded())) \(food.servingUnit)").tag(food.servingSize)
                ForEach(viewModel.servings) { serving in
                    Text("\(serving.label) — \(Int(serving.grams.rounded()))g").tag(serving.grams)
                }
            }
            .pickerStyle(.menu)
            Stepper(value: $viewModel.quantity, in: 0.25...10, step: 0.25) {
                Text("Quantity: \(viewModel.quantity, specifier: "%.2g")")
            }
            .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
            let payload = FoodLogSnapshotBuilder.payload(logID: "preview", food: food, servingGrams: viewModel.selectedServingGrams == 0 ? food.servingSize : viewModel.selectedServingGrams, quantity: viewModel.quantity)
            Text("Snapshot: \(Int(payload.calories.rounded())) kcal · P \(Int(payload.protein_g.rounded())) C \(Int(payload.carbs_g.rounded())) F \(Int(payload.fat_g.rounded()))")
                .font(.caption)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
        }
        .premiumCard()
    }
}
