import Foundation
import UIKit

// MARK: - FilmShotUploader

/// Uploads captured shot data to Supabase Storage.
/// Maintains a small in-memory retry queue so shots survive brief network blips.
@MainActor
final class FilmShotUploader {
    static let shared = FilmShotUploader()

    private struct PendingUpload {
        let imageData: Data
        let filmID: String
        let memberID: String
        var attempts: Int = 0
    }

    private var queue: [PendingUpload] = []
    private var isUploading = false
    private let maxRetries = 3

    private init() {}

    // MARK: - Public API

    /// Enqueues a JPEG image for upload, then starts the upload loop if idle.
    func enqueue(imageData: Data, filmID: String, memberID: String) {
        queue.append(PendingUpload(imageData: imageData, filmID: filmID, memberID: memberID))
        if !isUploading {
            Task { await processQueue() }
        }
    }

    // MARK: - Upload Loop

    private func processQueue() async {
        isUploading = true
        while !queue.isEmpty {
            var upload = queue.removeFirst()
            do {
                try await uploadShot(upload)
            } catch {
                upload.attempts += 1
                if upload.attempts < maxRetries {
                    queue.append(upload)
                    try? await Task.sleep(for: .seconds(2 * upload.attempts))
                }
                // Silently drop after maxRetries to avoid blocking the queue forever.
            }
        }
        isUploading = false
    }

    // MARK: - Supabase Storage Upload

    private func uploadShot(_ upload: PendingUpload) async throws {
        let path = "\(upload.filmID)/\(upload.memberID)/\(UUID().uuidString).jpg"
        let uploadURL = URL(string: "\(AppConfig.supabaseURL)/storage/v1/object/film-shots/\(path)")!

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = upload.imageData

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown
        }

        // Record the shot in the database now that the file is safely uploaded.
        _ = try await FilmService.shared.recordShot(
            filmID: upload.filmID,
            memberID: upload.memberID,
            storagePath: path
        )
    }
}
