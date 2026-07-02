import Foundation
import SwiftUI
import Combine

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var completedOrder: LocalOrder?

    private let airalo = AiraloClient.shared
    private let orderStore = LocalOrderStore.shared

    func purchase(package pkg: ESIMPackage, country: Country, userID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let order = try await airalo.placeOrder(packageID: pkg.packageID)
            guard let sim = order.sims.first else { throw APIError.notFound }

            let local = LocalOrder(
                id: UUID().uuidString,
                userID: userID,
                airaloOrderID: order.id,
                airaloOrderCode: order.code,
                packageID: pkg.packageID,
                packageTitle: pkg.title,
                countryCode: country.code,
                countryName: country.name,
                dataText: pkg.data,
                validityDays: pkg.day,
                price: pkg.price,
                iccid: sim.iccid,
                lpa: sim.lpa ?? "",
                matchingID: sim.matchingID ?? "",
                qrcode: sim.qrcode ?? "",
                qrcodeURL: sim.qrcodeURL,
                directAppleInstallURL: sim.directAppleInstallationURL,
                createdAt: Date()
            )
            orderStore.save(local, for: userID)
            completedOrder = local
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
