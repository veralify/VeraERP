import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSignUpMode = false

    private let supabase = SupabaseClient.shared

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6
    }

    func submit() async {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password (min 6 characters)"
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            if isSignUpMode {
                _ = try await supabase.signUp(email: email, password: password)
            } else {
                _ = try await supabase.signIn(email: email, password: password)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
