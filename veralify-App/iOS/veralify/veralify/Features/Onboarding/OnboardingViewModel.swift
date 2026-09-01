import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var draft: OnboardingDraft
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var communityState: CommunityLoadState = .idle

    private let repository = OnboardingRepository()
    private let communityRepository = CommunityRepository()

    init() {
        draft = repository.loadDraftLocally()
    }

    func advance() async {
        guard let next = OnboardingStateMachine.next(after: step) else { return }
        do {
            try await saveCurrentStep()
            step = next
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBack() {
        guard let previous = OnboardingStateMachine.previous(before: step) else { return }
        step = previous
    }

    func updateDraft(_ mutate: (inout OnboardingDraft) -> Void) {
        mutate(&draft)
        repository.saveDraftLocally(draft)
    }

    func computePlan() -> NutritionPlan {
        PlanCalculator.compute(
            weightKg: draft.weightKg,
            heightCm: draft.heightCm,
            age: draft.age,
            sex: draft.sex,
            activityLevel: draft.activityLevel,
            goal: draft.selectedGoal
        )
    }

    func savePlanAndAdvance() async {
        let plan = computePlan()
        updateDraft { $0.plan = plan }
        await advance()
    }

    func loadCommunities() async {
        communityState = .loading
        do {
            let groups = try await communityRepository.recommendedGroups(goalType: draft.selectedGoal)
            communityState = groups.isEmpty ? .notYetAvailable : .loaded(groups)
        } catch {
            communityState = .notYetAvailable
        }
    }

    func complete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.completeOnboarding()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func saveCurrentStep() async throws {
        isSaving = true
        defer { isSaving = false }
        switch step {
        case .welcome:
            repository.saveDraftLocally(draft)
        case .goalSelection:
            try await repository.saveGoalChoice(draft)
        case .profileSetup:
            try await repository.saveProfileSetup(draft)
        case .targetSetup:
            try await repository.saveTarget(draft)
        case .planReveal:
            let plan = computePlan()
            try await repository.savePlan(draft, plan: plan)
        case .paywall, .communitySetup:
            repository.saveDraftLocally(draft)
        }
    }
}
