import Foundation

/// Packaged-food nutrition facts resolved from a scanned barcode.
struct BarcodeProduct: Hashable {
    var name: String
    var brand: String?
    var calories: Int
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var servingDescription: String
}

enum BarcodeLookupError: LocalizedError {
    case notFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No product found for this barcode."
        case .invalidResponse:
            return "Couldn't read nutrition data for this product."
        }
    }
}

/// Looks up packaged food nutrition facts from the free, keyless Open Food
/// Facts database (https://world.openfoodfacts.org) — Veralify's equivalent
/// of Cal AI's barcode-scan flow. No API key or backend round-trip needed.
actor BarcodeLookupService {
    static let shared = BarcodeLookupService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    func lookup(barcode: String) async throws -> BarcodeProduct {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: nil)
        }

        let decoded: OpenFoodFactsResponse
        do {
            decoded = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw BarcodeLookupError.notFound
        }
        guard let nutriments = product.nutriments else {
            throw BarcodeLookupError.invalidResponse
        }

        guard let calories = nutriments.energy_kcal_serving ?? nutriments.energy_kcal_100g else {
            throw BarcodeLookupError.invalidResponse
        }

        return BarcodeProduct(
            name: product.product_name?.isEmpty == false ? product.product_name! : "Unknown product",
            brand: product.brands,
            calories: Int(calories.rounded()),
            proteinGrams: nutriments.proteins_serving ?? nutriments.proteins_100g ?? 0,
            carbGrams: nutriments.carbohydrates_serving ?? nutriments.carbohydrates_100g ?? 0,
            fatGrams: nutriments.fat_serving ?? nutriments.fat_100g ?? 0,
            servingDescription: product.serving_size ?? "100 g"
        )
    }
}

// MARK: - Open Food Facts response models

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let nutriments: OFFNutriments?
}

private struct OFFNutriments: Decodable {
    let energy_kcal_100g: Double?
    let energy_kcal_serving: Double?
    let proteins_100g: Double?
    let proteins_serving: Double?
    let carbohydrates_100g: Double?
    let carbohydrates_serving: Double?
    let fat_100g: Double?
    let fat_serving: Double?
}
