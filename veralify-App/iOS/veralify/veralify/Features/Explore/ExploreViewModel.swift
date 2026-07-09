import Foundation
import SwiftUI
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var selectedCategory: PlanCategory = .local
    @Published var searchText = ""
    @Published var globalPackages: [ESIMPackage] = []
    @Published var isLoadingGlobal = false
    @Published var errorMessage: String?

    private let esimGo = ESIMGoClient.shared

    let countries = Country.popular

    var filteredCountries: [Country] {
        if searchText.isEmpty { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var regionalPackages: [ESIMPackage] {
        globalPackages.filter { $0.planCategory == .regional }
    }

    var worldwidePackages: [ESIMPackage] {
        globalPackages.filter { $0.planCategory == .global }
    }

    func loadGlobalPackages() async {
        guard globalPackages.isEmpty else { return }
        isLoadingGlobal = true
        errorMessage = nil
        do {
            globalPackages = try await esimGo.getPackages(type: .global)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingGlobal = false
    }
}
