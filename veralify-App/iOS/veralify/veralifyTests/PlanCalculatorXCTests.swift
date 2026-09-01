import XCTest
@testable import veralify

final class PlanCalculatorXCTests: XCTestCase {
    func testMaleCutPlanUsesMifflinActivityAndDeficit() {
        let plan = PlanCalculator.compute(
            weightKg: 80,
            heightCm: 180,
            age: 30,
            sex: .male,
            activityLevel: .moderate,
            goal: .loseWeight
        )
        XCTAssertEqual(plan.bmr, 1775)
        XCTAssertEqual(plan.tdee, 2751)
        XCTAssertEqual(plan.dailyCalories, 2251)
        XCTAssertEqual(plan.proteinGrams, 160)
        XCTAssertEqual(plan.fatGrams, 64)
        XCTAssertEqual(plan.carbGrams, 259)
    }

    func testFemaleBulkPlanUsesSurplusAndBulkProtein() {
        let plan = PlanCalculator.compute(
            weightKg: 60,
            heightCm: 165,
            age: 28,
            sex: .female,
            activityLevel: .light,
            goal: .gainMuscle
        )
        XCTAssertEqual(plan.bmr, 1330)
        XCTAssertEqual(plan.tdee, 1829)
        XCTAssertEqual(plan.dailyCalories, 2079)
        XCTAssertEqual(plan.proteinGrams, 108)
        XCTAssertEqual(plan.fatGrams, 48)
        XCTAssertEqual(plan.carbGrams, 304)
    }

    func testUnspecifiedMaintenancePlanUsesMidpointSexConstant() {
        let plan = PlanCalculator.compute(
            weightKg: 70,
            heightCm: 170,
            age: 40,
            sex: .unspecified,
            activityLevel: .sedentary,
            goal: .maintain
        )
        XCTAssertEqual(plan.bmr, 1485)
        XCTAssertEqual(plan.tdee, 1782)
        XCTAssertEqual(plan.dailyCalories, 1782)
        XCTAssertEqual(plan.proteinGrams, 112)
        XCTAssertEqual(plan.fatGrams, 56)
        XCTAssertEqual(plan.carbGrams, 208)
    }

    func testRecompNeverDropsBelowBMR() {
        let plan = PlanCalculator.compute(
            weightKg: 45,
            heightCm: 150,
            age: 70,
            sex: .female,
            activityLevel: .sedentary,
            goal: .recomp
        )
        XCTAssertGreaterThanOrEqual(plan.dailyCalories, plan.bmr)
        XCTAssertEqual(plan.proteinGrams, 90)
    }

    func testUnitConversionsRoundTrip() {
        XCTAssertEqual(UnitConversion.poundsToKilograms(220.46226218), 100, accuracy: 0.0001)
        XCTAssertEqual(UnitConversion.inchesToCentimeters(70), 177.8, accuracy: 0.0001)
        XCTAssertEqual(UnitConversion.centimetersToInches(177.8), 70, accuracy: 0.0001)
    }
}
