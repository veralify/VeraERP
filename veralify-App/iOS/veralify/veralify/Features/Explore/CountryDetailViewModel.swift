import Foundation
import SwiftUI
import Combine

@MainActor
final class CountryDetailViewModel: ObservableObject {
    @Published var packages: [ESIMPackage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let esimGo = ESIMGoClient.shared

    func load(countryCode: String) async {
        isLoading = true
        errorMessage = nil
        do {
            packages = try await esimGo.getPackages(countryCode: countryCode, type: .local)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
