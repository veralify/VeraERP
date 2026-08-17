import Foundation
import SwiftUI
import Combine

/// Drives the Calories tab: today's totals vs. goals, the food log list,
/// and the three logging flows (photo, barcode, text description).
@MainActor
final class CaloriesViewModel: ObservableObject {
    @Published private(set) var todayEntries: [FoodEntry] = []
    @Published var goals: NutritionGoals
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    /// Pending analysis result awaiting user confirmation before it's saved.
    @Published var pendingConfirmation: PendingFoodConfirmation?

    private let store = FoodLogStore.shared
    private let analysisService = NutritionAnalysisService.shared
    private let barcodeService = BarcodeLookupService.shared

    init() {
        goals = store.goals()
        reload()
    }

    func reload() {
        todayEntries = store.entries(on: Date())
        goals = store.goals()
    }

    // MARK: - Totals

    var caloriesEaten: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    var proteinEaten: Double { todayEntries.reduce(0) { $0 + $1.proteinGrams } }
    var carbsEaten: Double { todayEntries.reduce(0) { $0 + $1.carbGrams } }
    var fatEaten: Double { todayEntries.reduce(0) { $0 + $1.fatGrams } }
    var caloriesRemaining: Int { max(0, goals.dailyCalories - caloriesEaten) }
    var calorieProgress: Double {
        guard goals.dailyCalories > 0 else { return 0 }
        return min(Double(caloriesEaten) / Double(goals.dailyCalories), 1.0)
    }

    // MARK: - Logging flows

    /// Analyzes a captured meal photo and stages the result for confirmation.
    func analyzePhoto(_ imageData: Data) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await analysisService.analyzePhoto(imageData)
            pendingConfirmation = PendingFoodConfirmation(
                source: .photo,
                name: result.name,
                servingDescription: result.servingDescription,
                calories: result.calories,
                proteinGrams: result.proteinGrams,
                carbGrams: result.carbGrams,
                fatGrams: result.fatGrams,
                detectedIngredients: result.detectedIngredients,
                thumbnailData: imageData
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Analyzes a free-text meal description and stages the result.
    func analyzeDescription(_ text: String) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await analysisService.analyzeDescription(text)
            pendingConfirmation = PendingFoodConfirmation(
                source: .text,
                name: result.name,
                servingDescription: result.servingDescription,
                calories: result.calories,
                proteinGrams: result.proteinGrams,
                carbGrams: result.carbGrams,
                fatGrams: result.fatGrams,
                detectedIngredients: result.detectedIngredients,
                thumbnailData: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Looks up a scanned barcode's nutrition facts and stages the result.
    func lookupBarcode(_ code: String) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let product = try await barcodeService.lookup(barcode: code)
            pendingConfirmation = PendingFoodConfirmation(
                source: .barcode,
                name: product.name,
                brand: product.brand,
                servingDescription: product.servingDescription,
                calories: product.calories,
                proteinGrams: product.proteinGrams,
                carbGrams: product.carbGrams,
                fatGrams: product.fatGrams,
                detectedIngredients: [],
                thumbnailData: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves the (possibly user-edited) pending confirmation to today's log.
    func confirmPendingEntry() {
        guard let pending = pendingConfirmation else { return }
        let entry = FoodEntry(
            name: pending.name,
            brand: pending.brand,
            calories: pending.calories,
            proteinGrams: pending.proteinGrams,
            carbGrams: pending.carbGrams,
            fatGrams: pending.fatGrams,
            servingDescription: pending.servingDescription,
            source: pending.source,
            thumbnailData: pending.thumbnailData
        )
        store.save(entry)
        pendingConfirmation = nil
        reload()
    }

    func discardPendingEntry() {
        pendingConfirmation = nil
    }

    func delete(_ entry: FoodEntry) {
        store.delete(entry)
        reload()
    }

    func saveGoals(_ goals: NutritionGoals) {
        store.saveGoals(goals)
        self.goals = goals
    }
}

/// Editable draft awaiting the user's confirmation ("Fix Results" in Cal
/// AI) before it's committed to the food log.
struct PendingFoodConfirmation: Identifiable {
    let id = UUID()
    var source: FoodEntrySource
    var name: String
    var brand: String? = nil
    var servingDescription: String
    var calories: Int
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var detectedIngredients: [String]
    var thumbnailData: Data?
}
