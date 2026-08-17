import SwiftUI
import AVFoundation

/// Full-screen barcode scanner used for the packaged-food lookup flow.
struct BarcodeScannerView: View {
    let onScanned: (String) -> Void

    @StateObject private var session = BarcodeScannerSession()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettingsAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: session.captureSession)
                .ignoresSafeArea()
                .overlay(scanFrame)

            VStack {
                topBar
                Spacer()
                Text("Point the camera at a barcode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 60)
            }
        }
        .task {
            session.onCodeScanned = { code in
                dismiss()
                onScanned(code)
            }
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
            Text("Allow camera access in Settings to scan barcodes.")
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
            .accessibilityLabel("Close scanner")

            Spacer()

            Text("Scan Barcode")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var scanFrame: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.white, lineWidth: 3)
            .frame(width: 260, height: 160)
    }
}
