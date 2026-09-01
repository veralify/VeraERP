import SwiftUI

struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(EntitlementStore.self) private var entitlementStore
    let onCompleted: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    progressBar
                    currentStep
                }
            }
            .toolbar { toolbar }
            .alert("Onboarding error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeScreen(
                getStarted: { Task { await viewModel.advance() } },
                signIn: { Task { try? await SupabaseClient.shared.signOut() } }
            )
        case .goalSelection:
            GoalSelectionScreen(viewModel: viewModel)
        case .profileSetup:
            ProfileSetupScreen(viewModel: viewModel)
        case .targetSetup:
            TargetSetupScreen(viewModel: viewModel)
        case .planReveal:
            PlanRevealScreen(viewModel: viewModel)
        case .paywall:
            OnboardingPaywallScreen(canContinue: !entitlementStore.activeKeys.isEmpty) {
                Task { await viewModel.advance() }
            }
        case .communitySetup:
            CommunitySetupScreen(viewModel: viewModel) {
                Task {
                    if await viewModel.complete() { onCompleted() }
                }
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: Double(viewModel.step.rawValue + 1), total: Double(OnboardingStep.allCases.count))
            .tint(VeraTokens.Colors.primary)
            .padding(.horizontal, VeraTokens.Spacing._5)
            .padding(.top, VeraTokens.Spacing._4)
            .accessibilityLabel("Onboarding progress")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.step != .welcome {
                Button("Back") { viewModel.goBack() }
                    .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
            }
        }
    }
}

private struct WelcomeScreen: View {
    let getStarted: () -> Void
    let signIn: () -> Void

    var body: some View {
        VStack(spacing: VeraTokens.Spacing._8) {
            Spacer()
            VStack(spacing: VeraTokens.Spacing._4) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(AppTheme.premiumGradient)
                    .accessibilityHidden(true)
                Text("Track. Connect. Transform.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(VeraTokens.Colors.fg)
                Text("Build your Veralify plan with clear nutrition targets and a community-ready profile.")
                    .font(.body)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: VeraTokens.Spacing._3) {
                Button("Get Started", action: getStarted)
                    .buttonStyle(PrimaryOnboardingButtonStyle())
                    .accessibilityLabel("Get started with onboarding")
                Button("Sign In with a different account", action: signIn)
                    .frame(maxWidth: .infinity, minHeight: VeraTokens.SafeArea.minimumHitTarget)
            }
        }
        .padding(VeraTokens.Spacing._5)
    }
}

private struct GoalSelectionScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScroll(title: "Choose your goal", subtitle: "This creates your active goal using the backend goals schema.") {
            LazyVGrid(columns: [GridItem(.flexible())], spacing: VeraTokens.Spacing._3) {
                ForEach(OnboardingGoalType.allCases) { goal in
                    Button {
                        viewModel.updateDraft { $0.selectedGoal = goal }
                    } label: {
                        HStack(spacing: VeraTokens.Spacing._3) {
                            Image(systemName: viewModel.draft.selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(VeraTokens.Colors.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.title).font(.headline)
                                Text(goal.subtitle).font(.caption).foregroundStyle(VeraTokens.Colors.fgMuted)
                            }
                            Spacer()
                        }
                        .foregroundStyle(VeraTokens.Colors.fg)
                        .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
                        .premiumCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Goal: \(goal.title)")
                }
            }
            ContinueButton(isSaving: viewModel.isSaving) { Task { await viewModel.advance() } }
        }
    }
}

private struct ProfileSetupScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScroll(title: "Set up your profile", subtitle: "Stored as canonical metric values in profiles and profile_preferences.") {
            Picker("Units", selection: unitsBinding) {
                ForEach(UnitsSystem.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Unit system")

            GroupBox("Body") {
                VStack(spacing: VeraTokens.Spacing._3) {
                    NumberField(label: heightLabel, value: heightDisplayBinding, suffix: heightSuffix)
                    NumberField(label: weightLabel, value: weightDisplayBinding, suffix: weightSuffix)
                    Stepper("Age: \(viewModel.draft.age)", value: ageBinding, in: 13...100)
                        .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
                        .accessibilityLabel("Age \(viewModel.draft.age)")
                }
            }

            GroupBox("Biology and activity") {
                VStack(spacing: VeraTokens.Spacing._3) {
                    Picker("Sex for BMR formula", selection: sexBinding) {
                        ForEach(BiologicalSex.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Activity", selection: activityBinding) {
                        ForEach(ProfileActivityLevel.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            ContinueButton(isSaving: viewModel.isSaving) { Task { await viewModel.advance() } }
        }
    }

    private var unitsBinding: Binding<UnitsSystem> { Binding(get: { viewModel.draft.units }, set: { newValue in viewModel.updateDraft { $0.units = newValue } }) }
    private var sexBinding: Binding<BiologicalSex> { Binding(get: { viewModel.draft.sex }, set: { sex in viewModel.updateDraft { $0.sex = sex } }) }
    private var activityBinding: Binding<ProfileActivityLevel> { Binding(get: { viewModel.draft.activityLevel }, set: { level in viewModel.updateDraft { $0.activityLevel = level } }) }
    private var ageBinding: Binding<Int> { Binding(get: { viewModel.draft.age }, set: { age in viewModel.updateDraft { $0.age = age } }) }
    private var heightLabel: String { viewModel.draft.units == .metric ? "Height" : "Height" }
    private var weightLabel: String { "Current weight" }
    private var heightSuffix: String { viewModel.draft.units == .metric ? "cm" : "in" }
    private var weightSuffix: String { viewModel.draft.units == .metric ? "kg" : "lb" }
    private var heightDisplayBinding: Binding<Double> {
        Binding(
            get: { viewModel.draft.units == .metric ? viewModel.draft.heightCm : UnitConversion.centimetersToInches(viewModel.draft.heightCm) },
            set: { value in viewModel.updateDraft { $0.heightCm = viewModel.draft.units == .metric ? value : UnitConversion.inchesToCentimeters(value) } }
        )
    }
    private var weightDisplayBinding: Binding<Double> {
        Binding(
            get: { viewModel.draft.units == .metric ? viewModel.draft.weightKg : UnitConversion.kilogramsToPounds(viewModel.draft.weightKg) },
            set: { value in viewModel.updateDraft { $0.weightKg = viewModel.draft.units == .metric ? value : UnitConversion.poundsToKilograms(value) } }
        )
    }
}

private struct TargetSetupScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScroll(title: "Target setup", subtitle: "Pick the target used to generate your deterministic nutrition plan.") {
            NumberField(label: "Target weight", value: targetWeightDisplayBinding, suffix: viewModel.draft.units == .metric ? "kg" : "lb")
            DatePicker("Target date", selection: targetDateBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .accessibilityLabel("Target date")
            ContinueButton(isSaving: viewModel.isSaving) { Task { await viewModel.advance() } }
        }
    }

    private var targetDateBinding: Binding<Date> { Binding(get: { viewModel.draft.targetDate }, set: { date in viewModel.updateDraft { $0.targetDate = date } }) }
    private var targetWeightDisplayBinding: Binding<Double> {
        Binding(
            get: { viewModel.draft.units == .metric ? viewModel.draft.targetWeightKg : UnitConversion.kilogramsToPounds(viewModel.draft.targetWeightKg) },
            set: { value in viewModel.updateDraft { $0.targetWeightKg = viewModel.draft.units == .metric ? value : UnitConversion.poundsToKilograms(value) } }
        )
    }
}

private struct PlanRevealScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        let plan = viewModel.computePlan()
        OnboardingScroll(title: "Your personalized plan", subtitle: "Computed locally, then saved to goals and daily goal_targets.") {
            VStack(spacing: VeraTokens.Spacing._3) {
                PlanMetric(title: "Daily calories", value: "\(plan.dailyCalories)", unit: "kcal", color: VeraTokens.Colors.Nutrition.calories)
                HStack(spacing: VeraTokens.Spacing._3) {
                    PlanMetric(title: "Protein", value: "\(plan.proteinGrams)", unit: "g", color: VeraTokens.Colors.Nutrition.protein)
                    PlanMetric(title: "Fat", value: "\(plan.fatGrams)", unit: "g", color: VeraTokens.Colors.Nutrition.fat)
                    PlanMetric(title: "Carbs", value: "\(plan.carbGrams)", unit: "g", color: VeraTokens.Colors.Nutrition.carbs)
                }
                Text("BMR \(plan.bmr) · TDEE \(plan.tdee)")
                    .font(.caption)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
            }
            ContinueButton(title: "Save plan and continue", isSaving: viewModel.isSaving) { Task { await viewModel.savePlanAndAdvance() } }
        }
    }
}

private struct OnboardingPaywallScreen: View {
    let canContinue: Bool
    let continueAction: () -> Void
    @Environment(EntitlementStore.self) private var entitlementStore

    var body: some View {
        VStack(spacing: VeraTokens.Spacing._3) {
            PaywallView()
            Button(canContinue ? "Continue" : "Continue after subscription is active") {
                continueAction()
            }
            .buttonStyle(PrimaryOnboardingButtonStyle())
            .disabled(!canContinue)
            .padding(.horizontal, VeraTokens.Spacing._5)
            .accessibilityHint(canContinue ? "Continues to community setup" : "Subscribe or restore purchases first")
        }
        .task { await entitlementStore.refreshIfNeeded() }
    }
}

private struct CommunitySetupScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let finish: () -> Void

    var body: some View {
        OnboardingScroll(title: "Find your community", subtitle: "Recommended groups are loaded from the groups schema when available.") {
            Group {
                switch viewModel.communityState {
                case .idle, .loading:
                    ProgressView("Loading recommended groups…")
                        .frame(maxWidth: .infinity, minHeight: 140)
                case .notYetAvailable:
                    ShellEmptyStateView(
                        title: "Communities are not available yet",
                        message: "Groups are landing in batch 2. You can skip this honest placeholder and keep your onboarding state server-backed.",
                        systemImage: "person.3.fill",
                        ctaTitle: "Batch 2 pending",
                        ctaSystemImage: "clock"
                    )
                    .frame(minHeight: 300)
                case .loaded(let groups):
                    VStack(spacing: VeraTokens.Spacing._3) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name).font(.headline)
                                Text(group.description ?? "A Veralify community.").font(.caption).foregroundStyle(VeraTokens.Colors.fgMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .premiumCard()
                        }
                    }
                }
            }
            Button(viewModel.isSaving ? "Saving…" : "Skip for now") { finish() }
                .buttonStyle(PrimaryOnboardingButtonStyle())
                .disabled(viewModel.isSaving)
        }
        .task { await viewModel.loadCommunities() }
    }
}

private struct OnboardingScroll<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeraTokens.Spacing._5) {
                VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(VeraTokens.Colors.fg)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                }
                content
            }
            .padding(VeraTokens.Spacing._5)
        }
    }
}

private struct NumberField: View {
    let label: String
    @Binding var value: Double
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
                .accessibilityLabel(label)
            Text(suffix).foregroundStyle(VeraTokens.Colors.fgMuted)
        }
    }
}

private struct ContinueButton: View {
    var title: LocalizedStringKey = "Continue"
    let isSaving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSaving { ProgressView() } else { Text(title) }
        }
        .buttonStyle(PrimaryOnboardingButtonStyle())
        .disabled(isSaving)
    }
}

private struct PrimaryOnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(VeraTokens.Colors.onPrimary)
            .frame(maxWidth: .infinity, minHeight: VeraTokens.SafeArea.minimumHitTarget)
            .padding(.vertical, VeraTokens.Spacing._1)
            .background(Capsule().fill(VeraTokens.Colors.primary.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}

private struct PlanMetric: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(unit).font(.caption).foregroundStyle(VeraTokens.Colors.fgMuted)
            Text(title).font(.caption2).foregroundStyle(VeraTokens.Colors.fgSubtle).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .premiumCard()
        .accessibilityLabel("\(title), \(value) \(unit)")
    }
}
