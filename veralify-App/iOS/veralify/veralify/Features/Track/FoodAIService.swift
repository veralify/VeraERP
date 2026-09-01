import Foundation
import UIKit

private struct FoodAnalyzeRequest: Encodable {
    let image_base64: String
    let mime_type: String
}

@MainActor
final class FoodAIService {
    private let supabase = SupabaseClient.shared

    func analyze(image: UIImage) async throws -> FoodAnalysisResponse {
        guard let data = image.jpegData(compressionQuality: 0.72) else {
            throw APIError.httpError(statusCode: 400, message: "Could not encode image.")
        }
        let request = FoodAnalyzeRequest(image_base64: data.base64EncodedString(), mime_type: "image/jpeg")
        return try await supabase.invokeEdgeFunction("analyze-food", body: request, returning: FoodAnalysisResponse.self)
    }
}
