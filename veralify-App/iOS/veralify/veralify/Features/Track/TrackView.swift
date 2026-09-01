import PhotosUI
import SwiftUI
import UIKit

struct TrackView: View {
    @StateObject private var viewModel = TrackViewModel()
    @State private var selectedTab = "Food"
    @State private var isShowingManual = false
    @State private var isShowingCamera = false

    private let tabs = ["Food", "Progress", "Goals", "Trends"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Track section", selection: $selectedTab) {
                ForEach(tabs, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, VeraTokens.Spacing._4)
            .padding(.top, VeraTokens.Spacing._2)

            Group {
                if selectedTab == "Food" {
                    foodLogView
                } else {
                    placeholder(title: selectedTab, image: selectedTab == "Progress" ? "chart.xyaxis.line" : selectedTab == "Goals" ? "target" : "chart.line.uptrend.xyaxis")
                }
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Track")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Scan", systemImage: "camera.viewfinder") { isShowingCamera = true }
                    .accessibilityLabel("Scan food")
                Button("Log", systemImage: "plus") { isShowingManual = true }
                    .accessibilityLabel("Log food manually")
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $isShowingManual) { ManualFoodLogView(viewModel: viewModel) }
        .sheet(isPresented: $isShowingCamera) { FoodCameraView(viewModel: viewModel) }
        .alert("Track error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var foodLogView: some View {
        ScrollView {
            VStack(spacing: VeraTokens.Spacing._4) {
                dateNavigator
                if viewModel.isLoading && viewModel.snapshot == nil {
                    ProgressView("Loading food log…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let snapshot = viewModel.snapshot {
                    totalsCard(snapshot)
                    ForEach(snapshot.meals) { meal in
                        MealSectionView(meal: meal, edit: { item in
                            viewModel.edit(item)
                            isShowingManual = true
                        }, delete: { item in
                            Task { await viewModel.delete(item) }
                        })
                    }
                } else {
                    ShellEmptyStateView(
                        title: "No food data",
                        message: LocalizedStringKey(viewModel.errorMessage ?? "Pull to retry or log your first meal."),
                        systemImage: "fork.knife.circle.fill",
                        ctaTitle: "Log your first meal",
                        ctaSystemImage: "plus"
                    )
                    .frame(minHeight: 360)
                }
            }
            .padding(VeraTokens.Spacing._4)
            .safeAreaPadding(.bottom, VeraTokens.SafeArea.bottomNavClearance)
        }
        .gesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                Task {
                    if value.translation.width > 40 { await viewModel.previousDay() }
                    if value.translation.width < -40 { await viewModel.nextDay() }
                }
            }
        )
    }

    private var dateNavigator: some View {
        HStack {
            Button { Task { await viewModel.previousDay() } } label: {
                Image(systemName: "chevron.left")
                    .frame(width: VeraTokens.SafeArea.minimumHitTarget, height: VeraTokens.SafeArea.minimumHitTarget)
            }
            Spacer()
            Text(viewModel.dateTitle)
                .font(.headline)
                .accessibilityLabel("Selected date \(viewModel.dateTitle)")
            Spacer()
            Button { Task { await viewModel.nextDay() } } label: {
                Image(systemName: "chevron.right")
                    .frame(width: VeraTokens.SafeArea.minimumHitTarget, height: VeraTokens.SafeArea.minimumHitTarget)
            }
        }
        .premiumCard()
    }

    private func totalsCard(_ snapshot: TrackDaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Text("Daily totals")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VeraTokens.Spacing._3) {
                MacroProgress(title: "Calories", current: snapshot.totals.calories, target: snapshot.target("calories"), unit: "kcal", color: VeraTokens.Colors.Nutrition.calories)
                MacroProgress(title: "Protein", current: snapshot.totals.proteinG, target: snapshot.target("protein_g"), unit: "g", color: VeraTokens.Colors.Nutrition.protein)
                MacroProgress(title: "Carbs", current: snapshot.totals.carbsG, target: snapshot.target("carbs_g"), unit: "g", color: VeraTokens.Colors.Nutrition.carbs)
                MacroProgress(title: "Fat", current: snapshot.totals.fatG, target: snapshot.target("fat_g"), unit: "g", color: VeraTokens.Colors.Nutrition.fat)
            }
        }
        .premiumCard()
    }

    private func placeholder(title: String, image: String) -> some View {
        ShellEmptyStateView(
            title: LocalizedStringKey(title),
            message: "This Track section is preserved for its later build-order phase.",
            systemImage: image,
            ctaTitle: "Coming later",
            ctaSystemImage: "clock"
        )
    }
}

private struct MacroProgress: View {
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
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(current.rounded())) / \(Int((target ?? 0).rounded())) \(unit)")
                    .font(.caption2)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(VeraTokens.Colors.surfaceMuted)
                    Capsule().fill(color).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(Int(current.rounded())) of \(Int((target ?? 0).rounded())) \(unit)")
    }
}

private struct MealSectionView: View {
    let meal: MealSection
    let edit: (FoodLogItem) -> Void
    let delete: (FoodLogItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
            Label(meal.mealType.title, systemImage: meal.mealType.systemImage)
                .font(.headline)
                .foregroundStyle(VeraTokens.Colors.fg)
            if meal.items.isEmpty {
                Text("No \(meal.mealType.rawValue) logged.")
                    .font(.subheadline)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, VeraTokens.Spacing._2)
            } else {
                ForEach(meal.items) { item in
                    FoodLogItemRow(item: item, edit: { edit(item) }, delete: { delete(item) })
                }
            }
        }
        .premiumCard()
    }
}

private struct FoodLogItemRow: View {
    let item: FoodLogItem
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: VeraTokens.Spacing._3) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text("\(Int(item.nutrition.calories.rounded())) kcal · P \(Int(item.nutrition.proteinG.rounded())) C \(Int(item.nutrition.carbsG.rounded())) F \(Int(item.nutrition.fatG.rounded()))")
                    .font(.caption)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                if let confidence = item.confidence {
                    Text("AI confidence \(Int((confidence * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(VeraTokens.Colors.info)
                }
            }
            Spacer()
            Menu {
                Button("Edit", action: edit)
                Button("Delete", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: VeraTokens.SafeArea.minimumHitTarget, height: VeraTokens.SafeArea.minimumHitTarget)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
