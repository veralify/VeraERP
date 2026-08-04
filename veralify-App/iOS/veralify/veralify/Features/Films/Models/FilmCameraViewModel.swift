import SwiftUI
import AVFoundation
import Combine

// MARK: - FilmCameraViewModel

@MainActor
final class FilmCameraViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var session: FilmCameraSession
    @Published var showSettingsAlert = false
    @Published var didCapture = false

    // MARK: - Init

    init(film: Film, member: FilmMember) {
        session = FilmCameraSession(
            filmID: film.id,
            memberID: member.id,
            shotLimit: film.shotLimit,
            shotsUsed: member.shotsUsed
        )
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await session.start()
        if session.error == .permissionDenied {
            showSettingsAlert = true
        }
    }

    func onDisappear() {
        session.stop()
    }

    // MARK: - Actions

    func shoot() async {
        do {
            try await session.shoot()
            triggerShutterFeedback()
            didCapture = true
            // Brief visual confirmation, then reset
            try? await Task.sleep(for: .milliseconds(150))
            didCapture = false
        } catch FilmError.shotLimitReached {
            // UI already shows 0 remaining; no additional alert needed
        } catch {
            session.error = error as? FilmCameraError
        }
    }

    func flipCamera() {
        session.flipCamera()
    }

    // MARK: - Haptics

    private func triggerShutterFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
