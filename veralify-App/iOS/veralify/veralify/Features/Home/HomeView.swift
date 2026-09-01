import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var snapshot: HomeSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository = HomeRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await repository.loadToday()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeraTokens.Spacing._5) {
                header
                if viewModel.isLoading && viewModel.snapshot == nil {
                    ProgressView("Loading today…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if let snapshot = viewModel.snapshot {
                    progressSection(snapshot)
                    aiInsightTeaser
                    recommendedAction(snapshot)
                } else {
                    ShellEmptyStateView(
                        title: "Your data will appear here",
                        message: LocalizedStringKey(viewModel.errorMessage ?? "Finish onboarding and log your first meal to see today's nutrition progress."),
                        systemImage: "chart.pie.fill",
                        ctaTitle: "Log your first meal",
                        ctaSystemImage: "plus.circle.fill"
                    )
                    .frame(minHeight: 360)
                }
            }
            .padding(VeraTokens.Spacing._4)
            .safeAreaPadding(.bottom, VeraTokens.SafeArea.bottomNavClearance)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Home")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            Text("Today")
                .font(.largeTitle.bold())
                .foregroundStyle(VeraTokens.Colors.fg)
            Text("Your calorie and macro progress updates from backend goal targets and daily nutrition summaries.")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func progressSection(_ snapshot: HomeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Text(snapshot.goal?.title ?? "Nutrition targets")
                .font(.headline)
            MacroRingGrid(snapshot: snapshot)
            if snapshot.foodLogCount == 0 && (snapshot.summary?.mealCount ?? 0) == 0 {
                Text("Log your first meal to start filling these rings.")
                    .font(.subheadline)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
            }
        }
        .premiumCard()
    }

    private var aiInsightTeaser: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            Label("AI insight", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(VeraTokens.Colors.primary)
            Text("Insights arrive in a later AI phase. Once enabled, this card will explain patterns in your real nutrition data.")
                .font(.subheadline)
                .foregroundStyle(VeraTokens.Colors.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private func recommendedAction(_ snapshot: HomeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            Text("Recommended action")
                .font(.headline)
            Label(snapshot.foodLogCount == 0 ? "Log your first meal" : "Review today's macros", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VeraTokens.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }
}

private struct MacroRingGrid: View {
    let snapshot: HomeSnapshot

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VeraTokens.Spacing._3) {
            NutritionRing(title: "Calories", current: snapshot.summary?.calories ?? 0, target: snapshot.target("calories"), unit: "kcal", color: VeraTokens.Colors.Nutrition.calories)
            NutritionRing(title: "Protein", current: snapshot.summary?.proteinG ?? 0, target: snapshot.target("protein_g"), unit: "g", color: VeraTokens.Colors.Nutrition.protein)
            NutritionRing(title: "Carbs", current: snapshot.summary?.carbsG ?? 0, target: snapshot.target("carbs_g"), unit: "g", color: VeraTokens.Colors.Nutrition.carbs)
            NutritionRing(title: "Fat", current: snapshot.summary?.fatG ?? 0, target: snapshot.target("fat_g"), unit: "g", color: VeraTokens.Colors.Nutrition.fat)
        }
    }
}

private struct NutritionRing: View {
    let title: String
    let current: Double
    let target: Double?
    let unit: String
    let color: Color

    private var progress: Double {
        guard let target, target > 0 else { return 0 }
        return min(current / target, 1)
    }

    var body: some View {
        VStack(spacing: VeraTokens.Spacing._2) {
            ZStack {
                Circle().stroke(VeraTokens.Colors.surfaceMuted, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(current.rounded()))")
                        .font(.headline)
                    Text(target.map { "/ \(Int($0.rounded()))" } ?? "No target")
                        .font(.caption2)
                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                }
            }
            .frame(width: 112, height: 112)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(VeraTokens.Colors.fgSubtle)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(Int(current.rounded())) of \(Int((target ?? 0).rounded())) \(unit)")
    }
}
