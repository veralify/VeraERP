import SwiftUI
import AVFoundation

/// Full-screen camera used for the "snap a photo" meal-logging flow.
/// Unlike `FilmCameraView`, this allows retakes: the captured photo is
/// handed off for AI analysis only after the user confirms it.
struct FoodPhotoCaptureView: View {
    let onCaptured: (Data) -> Void

    @StateObject private var session = FoodCameraSession()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettingsAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: session.captureSession)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .task {
            await session.start()
            if session.error == .permissionDenied { showSettingsAlert = true }
        }
        .onDisappear { session.stop() }
        .alert("Camera Access Required", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Allow camera access in Settings to scan your food.")
        }
        .statusBar(hidden: true)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            Text("Scan Food")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            Text("Fit the whole meal in frame")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            shutterButton
        }
        .padding(.bottom, 52)
    }

    private var shutterButton: some View {
        Button {
            Task {
                guard let data = try? await session.capturePhoto() else { return }
                dismiss()
                onCaptured(data)
            }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 76, height: 76)
                Circle().stroke(.white.opacity(0.4), lineWidth: 3).frame(width: 90, height: 90)
            }
        }
        .disabled(session.isCapturing)
        .accessibilityLabel("Take photo")
        .scaleEffect(session.isCapturing ? 0.88 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: session.isCapturing)
    }
}
