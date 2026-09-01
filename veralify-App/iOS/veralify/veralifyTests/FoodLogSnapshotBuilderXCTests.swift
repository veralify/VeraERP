import XCTest
@testable import veralify

final class FoodLogSnapshotBuilderXCTests: XCTestCase {
    func testManualFoodSnapshotScalesFromCanonicalServing() {
        let food = FoodSearchResult(
            id: "food-1",
            name: "Greek Yogurt",
            brand: "Vera",
            calories: 120,
            proteinG: 20,
            carbsG: 8,
            fatG: 2,
            fiberG: 0,
            sugarG: 6,
            sodiumMg: 55,
            servingSize: 150,
            servingUnit: "g",
            source: "internal"
        )
        let payload = FoodLogSnapshotBuilder.payload(logID: "log-1", food: food, servingGrams: 100, quantity: 2)
        XCTAssertEqual(payload.food_log_id, "log-1")
        XCTAssertEqual(payload.food_id, "food-1")
        XCTAssertEqual(payload.grams ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(payload.calories, 160, accuracy: 0.001)
        XCTAssertEqual(payload.protein_g, 26.666, accuracy: 0.01)
        XCTAssertFalse(payload.ai_estimated)
        XCTAssertNil(payload.confidence)
    }

    func testResolvedAICandidateCopiesServerNutritionWithoutRecomputing() {
        let candidate = FoodAnalysisCandidate(
            name: "Chicken bowl",
            quantity: 1,
            unit: "bowl",
            grams: 420,
            nutrition: NutritionSnapshot(calories: 612, proteinG: 48, carbsG: 62, fatG: 18, fiberG: 9, sugarG: 6, sodiumMg: 720),
            confidence: 0.87,
            assumptions: ["portion from image"],
            provenance: .internal,
            foodID: "canonical-food"
        )
        let payload = FoodLogSnapshotBuilder.payload(logID: "log-ai", candidate: candidate)
        XCTAssertEqual(payload.calories, 612)
        XCTAssertEqual(payload.protein_g, 48)
        XCTAssertEqual(payload.carbs_g, 62)
        XCTAssertEqual(payload.fat_g, 18)
        XCTAssertEqual(payload.food_id, "canonical-food")
        XCTAssertEqual(payload.confidence, 0.87)
        XCTAssertFalse(payload.ai_estimated)
    }

    func testUnresolvedAICandidateIsMarkedEstimatedAndKeepsReturnedSnapshot() {
        let candidate = FoodAnalysisCandidate(
            name: "Unknown stew",
            quantity: 1,
            unit: "serving",
            grams: 300,
            nutrition: NutritionSnapshot(calories: 430, proteinG: 18, carbsG: 44, fatG: 20, fiberG: 6, sugarG: 8, sodiumMg: 500),
            confidence: 0.42,
            assumptions: [],
            provenance: .aiEstimatePendingVerification,
            foodID: nil
        )
        let payload = FoodLogSnapshotBuilder.payload(logID: "log-ai", candidate: candidate)
        XCTAssertNil(payload.food_id)
        XCTAssertTrue(payload.ai_estimated)
        XCTAssertEqual(payload.calories, 430)
    }
}
