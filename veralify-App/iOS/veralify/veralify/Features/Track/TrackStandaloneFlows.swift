import SwiftUI

struct ManualFoodLogStandaloneView: View {
    @StateObject private var viewModel = TrackViewModel()

    var body: some View {
        ManualFoodLogView(viewModel: viewModel)
            .task { await viewModel.load() }
    }
}

struct FoodCameraStandaloneView: View {
    @StateObject private var viewModel = TrackViewModel()

    var body: some View {
        FoodCameraView(viewModel: viewModel)
            .task { await viewModel.load() }
    }
}
