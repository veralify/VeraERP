import StoreKit
import Combine

// MARK: - FilmPurchaseManager

/// Manages one-time StoreKit 2 purchases for creating a film.
/// Each film tier maps to a non-consumable in-app product.
@MainActor
final class FilmPurchaseManager: ObservableObject {
    static let shared = FilmPurchaseManager()

    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published var purchaseError: String?

    private init() {}

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            availableProducts = try await Product.products(for: AppConfig.FilmProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func product(for memberLimit: Int) -> Product? {
        let id = AppConfig.FilmProductID.productID(for: memberLimit)
        return availableProducts.first { $0.id == id }
    }

    // MARK: - Purchase

    /// Purchases the tier product for the given member limit.
    /// Returns `true` on success, `false` if the user cancelled.
    @discardableResult
    func purchase(memberLimit: Int) async throws -> Bool {
        guard let product = product(for: memberLimit) else {
            throw FilmPurchaseError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw FilmPurchaseError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}

// MARK: - FilmPurchaseError

enum FilmPurchaseError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:    return "This film tier is currently unavailable. Please try again later."
        case .verificationFailed: return "Purchase verification failed. Contact support if you were charged."
        }
    }
}
