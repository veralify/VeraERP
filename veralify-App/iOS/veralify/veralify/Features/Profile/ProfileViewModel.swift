import Foundation
import Combine

private struct DisplayNamePayload: Encodable {
    let display_name: String
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var authUser: AuthUser?
    @Published var currentUser: VeraUser?
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false

    private let supabase = SupabaseClient.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let authUser = try await supabase.getUser()
            self.authUser = authUser
            let users: [VeraUser] = try await supabase.select(
                from: "profiles",
                filters: ["id": authUser.id]
            )
            currentUser = users.first
            displayName = users.first?.displayName ?? ""
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile() async {
        guard let user = currentUser else { return }
        isSaving = true
        defer { isSaving = false }

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
    }

    func signOut() async {
        try? await supabase.signOut()
    }
}
