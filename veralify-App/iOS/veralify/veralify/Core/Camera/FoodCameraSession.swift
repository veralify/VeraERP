import AVFoundation
import UIKit
import Combine

/// AVCaptureSession wrapper for the Calories tab's "snap a photo" flow.
/// Unlike `FilmCameraSession`, this allows retakes since food photos are
/// reviewed and confirmed before being logged.
@MainActor
final class FoodCameraSession: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isCapturing = false
    @Published var error: FoodCameraError?

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var pendingContinuation: CheckedContinuation<Data, Error>?

    func start() async {
        guard await requestCameraPermission() else {
            error = .permissionDenied
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            error = .deviceUnavailable
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
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

    /// Captures one photo and returns compressed JPEG data. Callers may
    /// invoke this repeatedly — no shot limit, unlike the film feature.
    func capturePhoto() async throws -> Data {
        guard !isCapturing else { throw FoodCameraError.captureFailed }
        isCapturing = true
        defer { isCapturing = false }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        let imageData: Data = try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        return UIImage(data: imageData)
            .flatMap { $0.jpegData(compressionQuality: 0.7) }
            ?? imageData
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

extension FoodCameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in self.pendingContinuation?.resume(throwing: error) }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor in self.pendingContinuation?.resume(throwing: FoodCameraError.captureFailed) }
            return
        }
        Task { @MainActor in self.pendingContinuation?.resume(returning: data) }
    }
}

enum FoodCameraError: LocalizedError, Equatable {
    case permissionDenied
    case deviceUnavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:  return "Camera access is required to scan food. Enable it in Settings."
        case .deviceUnavailable: return "Camera is unavailable on this device."
        case .captureFailed:     return "Failed to capture the photo. Please try again."
        }
    }
}
