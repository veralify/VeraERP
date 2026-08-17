import AVFoundation
import Combine

/// AVCaptureSession wrapper that scans for barcodes (EAN-13/8, UPC-A/E, Code
/// 128) on packaged foods, mirroring Cal AI's barcode-scan flow. Reports
/// each unique code once per session to avoid duplicate lookups while the
/// camera stays pointed at the same product.
@MainActor
final class BarcodeScannerSession: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var error: FoodCameraError?
    @Published private(set) var lastScannedCode: String?

    let captureSession = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let metadataQueue = DispatchQueue(label: "com.veralify.calories.barcode-scan")
    var onCodeScanned: ((String) -> Void)?

    func start() async {
        guard await requestCameraPermission() else {
            error = .permissionDenied
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            error = .deviceUnavailable
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]
        }
        captureSession.commitConfiguration()

        await Task.detached(priority: .userInitiated) { [weak self] in
            self?.captureSession.startRunning()
        }.value

        isReady = true
    }

    func stop() {
        Task.detached(priority: .background) { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    /// Call after handling a scanned code to allow scanning a new product.
    func resumeScanning() {
        lastScannedCode = nil
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

extension BarcodeScannerSession: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = object.stringValue
        else { return }

        Task { @MainActor in
            guard self.lastScannedCode != code else { return }
            self.lastScannedCode = code
            self.onCodeScanned?(code)
        }
    }
}
