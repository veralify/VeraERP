import Foundation

/// AI-estimated nutrition facts for a scanned or described meal.
struct NutritionAnalysisResult: Codable, Hashable {
    var name: String
    var servingDescription: String
    var calories: Int
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var detectedIngredients: [String]
}

private struct NutritionAnalyzeRequest: Encodable {
    let mode: String
    let imageBase64: String?
    let description: String?
}

/// Sends captured meal photos or free-text meal descriptions to Veralify's
/// backend gateway for AI-powered calorie/macro estimation — the "snap a
/// photo" and "describe your meal" flows Cal AI popularized. Falls back to
/// realistic mock estimates while `AppConfig.useMockGatewayResponses` is on
/// and no vision endpoint is deployed yet, matching `BackendService`'s
/// existing mock-first pattern for chat.
actor NutritionAnalysisService {
    static let shared = NutritionAnalysisService()

    private let baseURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL? = URL(string: AppConfig.backendGatewayBaseURL)) {
        self.baseURL = baseURL ?? URL(string: "https://api.veralify.com/v1")!
    }

    func analyzePhoto(_ imageData: Data) async throws -> NutritionAnalysisResult {
        if AppConfig.useMockGatewayResponses {
            try await Task.sleep(for: .milliseconds(900))
            return mockPhotoResult()
        }
        return try await requestAnalysis(mode: "photo", imageBase64: imageData.base64EncodedString(), description: nil)
    }

    func analyzeDescription(_ text: String) async throws -> NutritionAnalysisResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.httpError(statusCode: 400, message: "Describe what you ate first.")
        }
        if AppConfig.useMockGatewayResponses {
            try await Task.sleep(for: .milliseconds(600))
            return mockTextResult(for: text)
        }
        return try await requestAnalysis(mode: "text", imageBase64: nil, description: text)
    }

    private func requestAnalysis(
        mode: String,
        imageBase64: String?,
        description: String?
    ) async throws -> NutritionAnalysisResult {
        var request = URLRequest(url: baseURL.appending(path: "nutrition/analyze"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            NutritionAnalyzeRequest(mode: mode, imageBase64: imageBase64, description: description)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard 200...299 ~= http.statusCode else {
            throw APIError.httpError(statusCode: http.statusCode, message: nil)
        }

        do {
            return try decoder.decode(NutritionAnalysisResult.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Mock estimation

    private func mockPhotoResult() -> NutritionAnalysisResult {
        let presets: [NutritionAnalysisResult] = [
            NutritionAnalysisResult(
                name: "Grilled Chicken Salad",
                servingDescription: "1 bowl (~350g)",
                calories: 420, proteinGrams: 38, carbGrams: 22, fatGrams: 18,
                detectedIngredients: ["Grilled chicken", "Mixed greens", "Cherry tomatoes", "Olive oil"]
            ),
            NutritionAnalysisResult(
                name: "Caesar Salad with Croutons",
                servingDescription: "1 plate (~300g)",
                calories: 330, proteinGrams: 12, carbGrams: 20, fatGrams: 22,
                detectedIngredients: ["Lettuce", "Parmesan", "Croutons", "Cherry tomatoes"]
            ),
            NutritionAnalysisResult(
                name: "Salmon with Rice & Vegetables",
                servingDescription: "1 plate (~400g)",
                calories: 550, proteinGrams: 35, carbGrams: 48, fatGrams: 22,
                detectedIngredients: ["Salmon", "White rice", "Broccoli"]
            ),
            NutritionAnalysisResult(
                name: "Avocado Toast",
                servingDescription: "2 slices",
                calories: 380, proteinGrams: 10, carbGrams: 40, fatGrams: 20,
                detectedIngredients: ["Sourdough bread", "Avocado", "Olive oil"]
            )
        ]
        return presets.randomElement()!
    }

    private func mockTextResult(for text: String) -> NutritionAnalysisResult {
        let wordCount = max(text.split(separator: " ").count, 1)
        let calories = min(150 + wordCount * 45, 1200)
        return NutritionAnalysisResult(
            name: text.capitalized,
            servingDescription: "1 serving (estimated)",
            calories: calories,
            proteinGrams: (Double(calories) * 0.18 / 4).rounded(),
            carbGrams: (Double(calories) * 0.50 / 4).rounded(),
            fatGrams: (Double(calories) * 0.32 / 9).rounded(),
            detectedIngredients: []
        )
    }
}
