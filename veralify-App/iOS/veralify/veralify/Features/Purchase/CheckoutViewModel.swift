import Foundation
import SwiftUI
import Combine

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var completedOrder: LocalOrder?

    private let esimGo = ESIMGoClient.shared
    private let orderStore = LocalOrderStore.shared

    func purchase(package pkg: ESIMPackage, country: Country, userID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let order = try await esimGo.placeOrder(packageID: pkg.packageID)
            guard let sim = order.esims.first else { throw APIError.notFound }

            let local = LocalOrder(
                id: UUID().uuidString,
                userID: userID,
                airaloOrderID: 0,
                airaloOrderCode: order.orderReference,
                packageID: pkg.packageID,
                packageTitle: pkg.title,
                countryCode: country.code,
                countryName: country.name,
                dataText: pkg.data,
                validityDays: pkg.day,
                price: pkg.price,
                iccid: sim.iccid,
                lpa: sim.smdpAddress,
                matchingID: sim.matchingId,
                qrcode: "LPA:1$\(sim.smdpAddress)$\(sim.matchingId)",
                qrcodeURL: nil,
                directAppleInstallURL: sim.appleInstallUrl,
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
