import AVFoundation
import UIKit
import Combine

// MARK: - FilmCameraSession

/// AVCaptureSession wrapper enforcing disposable-camera rules:
/// - No live preview of previously taken shots
/// - No retakes: shutter fires immediately and the image is uploaded
/// - Shutter is disabled once the shot limit is reached
@MainActor
final class FilmCameraSession: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isReady = false
    @Published var isTakingShot = false
    @Published var shotsRemaining: Int
    @Published var error: FilmCameraError?
    @Published private(set) var capturedImageData: Data?

    // MARK: - Private

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var pendingContinuation: CheckedContinuation<Data, Error>?

    private let filmID: String
    private let memberID: String
    private let shotLimit: Int

    // MARK: - Init

    init(filmID: String, memberID: String, shotLimit: Int, shotsUsed: Int) {
        self.filmID = filmID
        self.memberID = memberID
        self.shotLimit = shotLimit
        self.shotsRemaining = max(0, shotLimit - shotsUsed)
        super.init()
    }

    // MARK: - Session Lifecycle

    func start() async {
        guard await requestCameraPermission() else {
            error = .permissionDenied
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = .deviceUnavailable
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }

        captureSession.commitConfiguration()

        // Run the heavy session start off the main actor.
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

    // MARK: - Shoot

    /// Captures one photo, uploads it, and decrements the remaining count.
    /// Throws if the shot limit has been reached.
    func shoot() async throws {
        guard shotsRemaining > 0 else { throw FilmError.shotLimitReached }
        guard !isTakingShot else { return }

        isTakingShot = true
        defer { isTakingShot = false }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        let imageData: Data = try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // Compress and enqueue — never write to Photos library.
        let compressed = UIImage(data: imageData)
            .flatMap { $0.jpegData(compressionQuality: 0.82) }
            ?? imageData

        FilmShotUploader.shared.enqueue(imageData: compressed, filmID: filmID, memberID: memberID)
        shotsRemaining -= 1
    }

    // MARK: - Camera Flip

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }

        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        if captureSession.canAddInput(newInput) { captureSession.addInput(newInput) }
        captureSession.commitConfiguration()
        currentCameraPosition = newPosition
    }

    // MARK: - Permission

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension FilmCameraSession: AVCapturePhotoCaptureDelegate {
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
            Task { @MainActor in self.pendingContinuation?.resume(throwing: FilmCameraError.captureFailed) }
            return
        }
        Task { @MainActor in self.pendingContinuation?.resume(returning: data) }
    }
}

// MARK: - FilmCameraError

enum FilmCameraError: LocalizedError {
    case permissionDenied
    case deviceUnavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:   return "Camera access is required to shoot. Enable it in Settings."
        case .deviceUnavailable:  return "Camera is unavailable on this device."
        case .captureFailed:      return "Failed to capture the photo. Please try again."
        }
    }
}
