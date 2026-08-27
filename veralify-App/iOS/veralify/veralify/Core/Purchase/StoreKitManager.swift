import Foundation
import Observation
import StoreKit

struct IAPValidationPayload: Codable, Hashable {
    let productID: String
    let transactionID: String
    let originalTransactionID: String
    let appAccountToken: String
    let signedTransactionJWS: String
    let environment: String
    let purchasedAt: String
}

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var productLoadError: String?
    private(set) var purchaseMessage: String?
    private(set) var queuedValidations: [IAPValidationPayload] = []

    private var updatesTask: Task<Void, Never>?
    private let backend = BackendService.shared
    private let supabase = SupabaseClient.shared

    private init() {}


    var proProducts: [Product] {
        let order = AppConfig.SubscriptionProductID.pro
        return products
            .filter { order.contains($0.id) }
            .sorted { (order.firstIndex(of: $0.id) ?? Int.max) < (order.firstIndex(of: $1.id) ?? Int.max) }
    }

    func startTransactionListener() {
        guard updatesTask == nil else { return }
        updatesTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result, shouldFinish: true)
            }
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: AppConfig.SubscriptionProductID.all)
            productLoadError = products.isEmpty ? "No StoreKit products returned. Configure App Store Connect products or StoreKit testing." : nil
        } catch {
            productLoadError = error.localizedDescription
            products = []
        }
    }

    func purchase(_ product: Product) async {
        purchaseMessage = nil
        do {
            let authUser = try await supabase.getUser()
            guard let appAccountToken = UUID(uuidString: authUser.id) else {
                purchaseMessage = "Your account cannot be linked to StoreKit. Please contact support."
                return
            }

            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let delivered = await validateWithBackend(transaction)
                if delivered {
                    await transaction.finish()
                    await EntitlementStore.shared.refresh()
                    purchaseMessage = "Purchase received. Access updates after server validation."
                } else {
                    purchaseMessage = "Purchase received but backend validation is not available yet. We'll retry; no entitlement was granted locally."
                }
            case .userCancelled:
                purchaseMessage = "Purchase cancelled."
            case .pending:
                purchaseMessage = "Purchase approval is pending. Access updates after Apple approves and the backend validates it."
            @unknown default:
                purchaseMessage = "Unknown purchase result."
            }
        } catch {
            purchaseMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await restoreCurrentEntitlements()
            await EntitlementStore.shared.refresh()
            purchaseMessage = "Restore checked. Access depends on backend entitlements."
        } catch {
            purchaseMessage = error.localizedDescription
        }
    }

    func restoreCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            await handle(transactionResult: result, shouldFinish: false)
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>, shouldFinish: Bool) async {
        do {
            let transaction = try checkVerified(transactionResult)
            guard transaction.revocationDate == nil else {
                await EntitlementStore.shared.refresh()
                if shouldFinish { await transaction.finish() }
                return
            }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                await EntitlementStore.shared.refresh()
                if shouldFinish { await transaction.finish() }
                return
            }
            let delivered = await validateWithBackend(transaction)
            if delivered {
                await EntitlementStore.shared.refresh()
                if shouldFinish { await transaction.finish() }
            }
        } catch {
            print("[StoreKitManager] Unverified transaction ignored: \(error)")
        }
    }

    private func validateWithBackend(_ transaction: Transaction) async -> Bool {
        guard let token = transaction.appAccountToken else {
            print("[StoreKitManager] Refusing validation without appAccountToken for transaction \(transaction.id)")
            return false
        }
        let payload = IAPValidationPayload(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            appAccountToken: token.uuidString,
            signedTransactionJWS: String(data: transaction.jsonRepresentation, encoding: .utf8) ?? "",
            environment: String(describing: transaction.environment),
            purchasedAt: Self.isoFormatter.string(from: transaction.purchaseDate)
        )
        do {
            try await backend.validateIAPTransaction(payload)
            return true
        } catch APIError.notFound {
            queueValidation(payload)
            print("[StoreKitManager] /api/v1/iap/validate not found; queued transaction \(transaction.id) for retry.")
            return false
        } catch {
            queueValidation(payload)
            print("[StoreKitManager] IAP validation failed; queued transaction \(transaction.id): \(error)")
            return false
        }
    }

    private func queueValidation(_ payload: IAPValidationPayload) {
        guard !queuedValidations.contains(payload) else { return }
        queuedValidations.append(payload)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    private static let isoFormatter = ISO8601DateFormatter()
}
