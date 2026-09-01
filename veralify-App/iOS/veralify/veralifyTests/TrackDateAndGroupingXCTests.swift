import XCTest
@testable import veralify

final class TrackDateAndGroupingXCTests: XCTestCase {
    func testDateNavigatorMovesByOneDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        XCTAssertEqual(DateNavigator.previousDay(before: date, calendar: calendar), calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!)
        XCTAssertEqual(DateNavigator.nextDay(after: date, calendar: calendar), calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!)
    }

    func testMealGroupingPlacesItemsUnderTheirMealType() {
        let breakfastGroup = MealGroup(id: "group-b", mealType: .breakfast, name: "Breakfast", loggedAt: "2026-09-01T08:00:00Z")
        let dinnerGroup = MealGroup(id: "group-d", mealType: .dinner, name: "Dinner", loggedAt: "2026-09-01T19:00:00Z")
        let breakfastLog = FoodLog(id: "log-b", mealGroupID: "group-b", loggedAt: "2026-09-01T08:10:00Z", notes: nil)
        let dinnerLog = FoodLog(id: "log-d", mealGroupID: "group-d", loggedAt: "2026-09-01T19:10:00Z", notes: nil)
        let oats = FoodLogItem(foodLogID: "log-b", foodID: "oats", name: "Oats", quantity: 1, unit: "bowl", grams: 80, nutrition: NutritionSnapshot(calories: 300, proteinG: 10, carbsG: 50, fatG: 6, fiberG: 8, sugarG: 1, sodiumMg: 5), confidence: nil, aiEstimated: false)
        let salmon = FoodLogItem(foodLogID: "log-d", foodID: "salmon", name: "Salmon", quantity: 1, unit: "fillet", grams: 150, nutrition: NutritionSnapshot(calories: 350, proteinG: 34, carbsG: 0, fatG: 22, fiberG: 0, sugarG: 0, sodiumMg: 80), confidence: nil, aiEstimated: false)

        let sections = MealGrouping.sections(groups: [breakfastGroup, dinnerGroup], logs: [breakfastLog, dinnerLog], items: [oats, salmon])
        XCTAssertEqual(sections.count, MealType.allCases.count)
        XCTAssertEqual(sections.first { $0.mealType == .breakfast }?.items.map(\.name), ["Oats"])
        XCTAssertEqual(sections.first { $0.mealType == .dinner }?.items.map(\.name), ["Salmon"])
        XCTAssertEqual(sections.first { $0.mealType == .snack }?.items, [])
    }
}
