import Combine
import Foundation
import PhotosUI
import UIKit

@MainActor
final class TrackViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var snapshot: TrackDaySnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMealType: MealType = .breakfast
    @Published var searchQuery = ""
    @Published var searchResults: [FoodSearchResult] = []
    @Published var servings: [FoodServing] = []
    @Published var selectedFood: FoodSearchResult?
    @Published var selectedServingGrams: Double = 0
    @Published var quantity: Double = 1
    @Published var isSaving = false
    @Published var selectedImage: UIImage?
    @Published var analysis: FoodAnalysisResponse?
    @Published var isAnalyzing = false
    @Published var editingItem: FoodLogItem?

    private let repository = TrackRepository()
    private let aiService = FoodAIService()

    var dateTitle: String {
        if DateNavigator.isToday(selectedDate) { return "Today" }
        return Self.titleFormatter.string(from: selectedDate)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await repository.loadDay(date: selectedDate)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            snapshot = nil
        }
    }

    func previousDay() async {
        selectedDate = DateNavigator.previousDay(before: selectedDate)
        await load()
    }

    func nextDay() async {
        selectedDate = DateNavigator.nextDay(after: selectedDate)
        await load()
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await repository.searchFoods(query: query)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(food: FoodSearchResult) async {
        selectedFood = food
        quantity = 1
        do {
            servings = try await repository.servings(for: food.id)
            selectedServingGrams = servings.first?.grams ?? food.servingSize
        } catch {
            servings = []
            selectedServingGrams = food.servingSize
        }
    }

    func saveSelectedFood() async {
        guard let selectedFood else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if let editingItem {
                _ = try await repository.update(item: editingItem, using: selectedFood, servingGrams: selectedServingGrams, quantity: quantity)
                self.editingItem = nil
            } else {
                _ = try await repository.log(food: selectedFood, mealType: selectedMealType, date: selectedDate, servingGrams: selectedServingGrams, quantity: quantity)
            }
            resetManualForm()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func edit(_ item: FoodLogItem) {
        editingItem = item
        searchQuery = item.name
        selectedServingGrams = item.grams ?? 100
        quantity = item.quantity
    }

    func delete(_ item: FoodLogItem) async {
        do {
            try await repository.delete(item: item)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func analyzeSelectedImage() async {
        guard let selectedImage else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            analysis = try await aiService.analyze(image: selectedImage)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            analysis = nil
        }
    }

    func confirm(candidate: FoodAnalysisCandidate) async {
        guard candidate.provenance != .aiEstimatePendingVerification else {
            searchQuery = candidate.name
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await repository.log(candidate: candidate, mealType: selectedMealType, date: selectedDate)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetManualForm() {
        searchQuery = ""
        searchResults = []
        servings = []
        selectedFood = nil
        selectedServingGrams = 0
        quantity = 1
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
