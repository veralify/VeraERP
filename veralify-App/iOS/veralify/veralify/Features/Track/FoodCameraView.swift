import PhotosUI
import SwiftUI
import UIKit

struct FoodCameraView: View {
    @ObservedObject var viewModel: TrackViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VeraTokens.Spacing._4) {
                    Picker("Meal", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    imagePickerCard
                    analysisState
                }
                .padding(VeraTokens.Spacing._4)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    viewModel.selectedImage = image
                    Task { await viewModel.analyzeSelectedImage() }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        viewModel.selectedImage = image
                        await viewModel.analyzeSelectedImage()
                    }
                }
            }
        }
    }

    private var imagePickerCard: some View {
        VStack(spacing: VeraTokens.Spacing._3) {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: VeraTokens.Radii.lg))
                    .accessibilityLabel("Selected food photo")
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(VeraTokens.Colors.primary)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .accessibilityHidden(true)
            }
            HStack(spacing: VeraTokens.Spacing._3) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Pick Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: VeraTokens.SafeArea.minimumHitTarget)
                }
                .buttonStyle(.borderedProminent)
                Button { isShowingCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity, minHeight: VeraTokens.SafeArea.minimumHitTarget)
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
        }
        .premiumCard()
    }

    @ViewBuilder
    private var analysisState: some View {
        if viewModel.isAnalyzing {
            ProgressView("Analyzing with Veralify Nutrition Engine…")
                .frame(maxWidth: .infinity, minHeight: 160)
                .premiumCard()
        } else if let response = viewModel.analysis {
            VStack(alignment: .leading, spacing: VeraTokens.Spacing._3) {
                Text("Candidates").font(.headline)
                Text("Overall confidence \(Int((response.overallConfidence * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(VeraTokens.Colors.fgMuted)
                ForEach(response.items) { candidate in
                    CandidateRow(candidate: candidate) {
                        Task { await viewModel.confirm(candidate: candidate) }
                    }
                }
            }
            .premiumCard()
        } else if let error = viewModel.errorMessage {
            VStack(spacing: VeraTokens.Spacing._3) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(VeraTokens.Colors.warning)
                Text("Analysis unavailable").font(.headline)
                Text(error).font(.subheadline).foregroundStyle(VeraTokens.Colors.fgMuted).multilineTextAlignment(.center)
                Text("If OPENROUTER_API_KEY is missing locally, configure it on the Supabase Edge Function and retry.")
                    .font(.caption)
                    .foregroundStyle(VeraTokens.Colors.fgSubtle)
                    .multilineTextAlignment(.center)
            }
            .premiumCard()
        } else {
            ShellEmptyStateView(title: "Take a food photo", message: "Images are sent to the live /analyze-food Edge Function. No fake response is generated.", systemImage: "camera.metering.matrix", ctaTitle: "Pick or capture", ctaSystemImage: "photo")
                .frame(minHeight: 300)
        }
    }
}

private struct CandidateRow: View {
    let candidate: FoodAnalysisCandidate
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VeraTokens.Spacing._2) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name).font(.headline)
                    Text("\(Int(candidate.grams.rounded()))g · \(Int(candidate.nutrition.calories.rounded())) kcal · confidence \(Int((candidate.confidence * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(VeraTokens.Colors.fgMuted)
                }
                Spacer()
                Text(candidate.provenance.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(candidate.provenance == .aiEstimatePendingVerification ? VeraTokens.Colors.warning : VeraTokens.Colors.success)
            }
            Text("P \(Int(candidate.nutrition.proteinG.rounded()))g · C \(Int(candidate.nutrition.carbsG.rounded()))g · F \(Int(candidate.nutrition.fatG.rounded()))g")
                .font(.caption)
                .foregroundStyle(VeraTokens.Colors.fgSubtle)
            Button(candidate.provenance == .aiEstimatePendingVerification ? "Search manually" : "Confirm") { confirm() }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: VeraTokens.SafeArea.minimumHitTarget)
        }
        .padding(.vertical, VeraTokens.Spacing._2)
        .accessibilityElement(children: .combine)
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView
        init(parent: CameraCaptureView) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
