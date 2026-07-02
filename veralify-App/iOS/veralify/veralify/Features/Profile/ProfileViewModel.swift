import Foundation
import Combine

// Extracted from ProfileViewModel to avoid Swift type-checker issues in async context
private struct DisplayNamePayload: Encodable {
    let display_name: String
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var currentUser: VeraUser?
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false

    private let supabase = SupabaseClient.shared

    func load() async {
        guard let authUser = try? await supabase.getUser() else { return }
        isLoading = true

        do {
            let users: [VeraUser] = try await supabase.select(
                from: "vera_users",
                filters: ["id": authUser.id]
            )
            currentUser = users.first
            displayName = users.first?.displayName ?? ""
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveProfile() async {
        guard let user = currentUser else { return }
        isSaving = true

        do {
            let payload = DisplayNamePayload(display_name: displayName)
            let updated: VeraUser = try await supabase.update(
                table: "vera_users",
                data: payload,
                returning: VeraUser.self,
                filters: ["id": user.id]
            )
            currentUser = updated
            saveSuccess = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func signOut() async {
        try? await supabase.signOut()
    }
}
