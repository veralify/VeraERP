import SwiftUI

/// Root screen for the Calories tab: today's ring, macro breakdown, and
/// recent food log — Veralify's clone of Cal AI's home screen.
struct CaloriesHomeView: View {
    @StateObject private var viewModel = CaloriesViewModel()

    @State private var showAddMenu = false
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case photoCapture
        case barcodeScanner
        case textEntry

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ringSection
                    macrosSection
                    logSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Calories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMenu = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .accessibilityLabel("Log a meal")
                }
            }
            .overlay {
                if viewModel.isAnalyzing {
                    analyzingOverlay
                }
            }
            .sheet(isPresented: $showAddMenu) {
                AddFoodMenuView { option in
                    switch option {
                    case .photo:   activeSheet = .photoCapture
                    case .barcode: activeSheet = .barcodeScanner
                    case .text:    activeSheet = .textEntry
                    }
                }
            }
            .fullScreenCover(item: $activeSheet) { sheet in
                switch sheet {
                case .photoCapture:
                    FoodPhotoCaptureView { data in
                        Task { await viewModel.analyzePhoto(data) }
                    }
                case .barcodeScanner:
                    BarcodeScannerView { code in
                        Task { await viewModel.lookupBarcode(code) }
                    }
                case .textEntry:
                    TextMealEntryView { text in
                        Task { await viewModel.analyzeDescription(text) }
                    }
                }
            }
            .sheet(item: Binding(
                get: { viewModel.pendingConfirmation },
                set: { viewModel.pendingConfirmation = $0 }
            )) { _ in
                FoodConfirmView(
                    pending: Binding(
                        get: { viewModel.pendingConfirmation ?? placeholderConfirmation },
                        set: { viewModel.pendingConfirmation = $0 }
                    ),
                    onConfirm: { viewModel.confirmPendingEntry() },
                    onCancel: { viewModel.discardPendingEntry() }
                )
            }
            .alert("Something Went Wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var placeholderConfirmation: PendingFoodConfirmation {
        PendingFoodConfirmation(
            source: .manual,
            name: "",
            servingDescription: "",
            calories: 0,
            proteinGrams: 0,
            carbGrams: 0,
            fatGrams: 0,
            detectedIngredients: []
        )
    }

    // MARK: - Sections

    private var ringSection: some View {
        VStack(spacing: 16) {
            CalorieRingView(
                eaten: viewModel.caloriesEaten,
                goal: viewModel.goals.dailyCalories,
                progress: viewModel.calorieProgress
            )
            Text("\(viewModel.caloriesRemaining) cal remaining today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var macrosSection: some View {
        HStack {
            MacroProgressRow(
                title: "Protein", systemImage: "flame.fill", color: .red,
                eaten: viewModel.proteinEaten, goal: viewModel.goals.proteinGrams
            )
            MacroProgressRow(
                title: "Carbs", systemImage: "leaf.fill", color: .orange,
                eaten: viewModel.carbsEaten, goal: viewModel.goals.carbGrams
            )
            MacroProgressRow(
                title: "Fat", systemImage: "drop.fill", color: .blue,
                eaten: viewModel.fatEaten, goal: viewModel.goals.fatGrams
            )
        }
        .premiumCard()
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Log")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)

            if viewModel.todayEntries.isEmpty {
                emptyLogState
            } else {
                ForEach(viewModel.todayEntries) { entry in
                    FoodLogRow(entry: entry)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyLogState: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No meals logged yet")
                .font(.subheadline.weight(.medium))
            Text("Tap + to scan your first meal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var analyzingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyzing meal…")
                .font(.subheadline.weight(.medium))
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    CaloriesHomeView()
}
