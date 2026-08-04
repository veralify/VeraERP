import SwiftUI
import AVFoundation

// MARK: - FilmCameraView

struct FilmCameraView: View {
    let film: Film
    let member: FilmMember

    @StateObject private var viewModel: FilmCameraViewModel
    @Environment(\.dismiss) private var dismiss

    init(film: Film, member: FilmMember) {
        self.film = film
        self.member = member
        _viewModel = StateObject(wrappedValue: FilmCameraViewModel(film: film, member: member))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live viewfinder
            CameraPreviewView(session: viewModel.session.captureSession)
                .ignoresSafeArea()
                .overlay(shutterFlash)

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .alert("Camera Access Required", isPresented: $viewModel.showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Allow camera access in Settings to shoot with this film.")
        }
        .statusBar(hidden: true)
    }

    // MARK: - Top Bar

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

            ShotCounterView(
                remaining: viewModel.session.shotsRemaining,
                limit: film.shotLimit
            )

            Spacer()

            Button { viewModel.flipCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Flip camera")
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 16) {
            if viewModel.session.shotsRemaining == 0 {
                Text("No shots left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 4)
            }

            shutterButton
        }
        .padding(.bottom, 52)
    }

    private var shutterButton: some View {
        Button {
            Task { await viewModel.shoot() }
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(.white.opacity(0.4), lineWidth: 3)
                    .frame(width: 90, height: 90)
            }
        }
        .disabled(viewModel.session.shotsRemaining == 0 || viewModel.session.isTakingShot)
        .accessibilityLabel("Take shot")
        .scaleEffect(viewModel.session.isTakingShot ? 0.88 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: viewModel.session.isTakingShot)
    }

    // MARK: - Shutter Flash

    private var shutterFlash: some View {
        Color.white
            .opacity(viewModel.didCapture ? 0.6 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.15), value: viewModel.didCapture)
    }
}

// MARK: - CameraPreviewView (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
