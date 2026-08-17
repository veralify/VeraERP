import Foundation

/// How a logged meal's nutrition info was determined.
enum FoodEntrySource: String, Codable, Hashable {
    case photo
    case barcode
    case text
    case manual
}
/// A single logged meal/food item, the core unit of the Calories feature —
/// Veralify's clone of Cal AI's photo/barcode/text meal logging.
struct FoodEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var brand: String?
    var calories: Int
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var servingDescription: String
    var source: FoodEntrySource
    var loggedAt: Date
    /// Small compressed JPEG thumbnail of the source photo, if any.
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        calories: Int,
        proteinGrams: Double,
        carbGrams: Double,
        fatGrams: Double,
        servingDescription: String,
        source: FoodEntrySource,
        loggedAt: Date = Date(),
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.servingDescription = servingDescription
        self.source = source
        self.loggedAt = loggedAt
        self.thumbnailData = thumbnailData
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var formattedTime: String { Self.timeFormatter.string(from: loggedAt) }
}
