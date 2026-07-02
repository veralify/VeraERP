import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Veralify")
                        .font(.largeTitle.bold())
                    Text("Verify. Trust. Simplify.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(viewModel.isSignUpMode ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
                .padding(.horizontal)

                Button {
                    viewModel.isSignUpMode.toggle()
                    viewModel.errorMessage = nil
                } label: {
                    Text(viewModel.isSignUpMode
                         ? "Already have an account? Sign in"
                         : "Don't have an account? Sign up")
                    .font(.footnote)
                }
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LoginView()
}
