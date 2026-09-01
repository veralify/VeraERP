import Foundation
import Combine

@MainActor
final class OnboardingStatusStore: ObservableObject {
    enum Status: Equatable {
        case loading
        case needsOnboarding
        case complete
        case failed(String)
    }

    @Published private(set) var status: Status = .loading
    private let repository = OnboardingRepository()

    func refresh() async {
        status = .loading
        do {
            let profile = try await repository.loadProfile()
            status = profile?.onboardingCompleted == true ? .complete : .needsOnboarding
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func markNeedsOnboarding() {
        status = .needsOnboarding
    }
}
