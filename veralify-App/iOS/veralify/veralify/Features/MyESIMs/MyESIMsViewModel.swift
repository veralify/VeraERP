import Foundation
import SwiftUI
import Combine

@MainActor
final class MyESIMsViewModel: ObservableObject {
    @Published var orders: [LocalOrder] = []
    @Published var usageMap: [String: SIMUsage] = [:]
    @Published var isLoadingUsage = false

    private let store = LocalOrderStore.shared
    private let airalo = AiraloClient.shared

    func load(userID: String) {
        orders = store.all(for: userID)
    }

    func fetchUsage(for order: LocalOrder) async {
        guard !order.iccid.isEmpty else { return }
        isLoadingUsage = true
        if let usage = try? await airalo.getSimUsage(iccid: order.iccid) {
            usageMap[order.iccid] = usage
        }
        isLoadingUsage = false
    }
}
