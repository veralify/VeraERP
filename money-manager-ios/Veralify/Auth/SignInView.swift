import AuthenticationServices
import SwiftUI

/// The first screen for anyone not signed in: Sign in with Apple, or a code
/// sent by email.
///
/// Both create the account on first use, so there is no separate sign-up.
/// Styled as the onboarding welcome step it comes before — same mark, same
/// type, same button shapes — so the two read as one flow.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth

    private enum Step: Equatable {
        case email
        case code(sentTo: String)
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    /// The nonce of the Apple request in flight; its hash went to Apple, the
    /// raw value goes to Supabase with the token that comes back.
    @State private var appleNonce: AppleNonce?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Centred when it fits; scrolls when it does not, as the
            // onboarding welcome does, so nothing falls off an iPhone SE at a
            // large text size.
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        switch step {
                        case .email: emailStep
                        case .code(let address): codeStep(address)
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 520, alignment: .leading)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .dismissibleKeyboard()
            }

            if isWorking {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.lime)
                    .accessibilityLabel("Signing in")
            }
        }
        .animation(.snappy(duration: 0.25), value: step)
        .disabled(isWorking)
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("€")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.lime.readableForeground)
                .frame(width: 62, height: 62)
                .background(Theme.lime, in: .rect(cornerRadius: 18))
                .accessibilityHidden(true)

            Text("Sign in to Veralify")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your plan, entries and receipts are kept in your account, so they're safe if you change phone and you can see them on the web too.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.continue) { request in
                let nonce = AppleNonce.make()
                appleNonce = nonce
                request.requestedScopes = [.email]
                request.nonce = nonce.sha256
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(.capsule)

            HStack(spacing: 12) {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Text("or")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Rectangle().fill(Theme.stroke).frame(height: 1)
            }
            .padding(.vertical, 4)

            FieldRow(label: "Email", placeholder: "you@example.com", text: $email, keyboard: .emailAddress, submitLabel: .send)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { sendCode() }

            PrimaryButton(title: "Email me a sign-in code", enabled: Self.isPlausibleEmail(email)) {
                sendCode()
            }
        }
    }

    private func codeStep(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("We sent a code to \(address). It expires in an hour.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FieldRow(label: "Code", placeholder: "123456", text: $code, keyboard: .numberPad)
                .textContentType(.oneTimeCode)

            PrimaryButton(title: "Sign in", enabled: Self.isPlausibleCode(code)) {
                verifyCode(address)
            }

            HStack {
                Button("Use a different email") {
                    code = ""
                    errorMessage = nil
                    step = .email
                }
                Spacer(minLength: 8)
                Button("Send a new code") {
                    resendCode(address)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.lime)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var footnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.lime)
            Text("Your data syncs over an encrypted connection and only you can see it. Scanned ID documents stay on this phone.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce
            else {
                errorMessage = String(localized: "Sign in with Apple didn't finish. Try again.")
                return
            }
            appleNonce = nil
            perform { try await auth.signInWithApple(idToken: idToken, nonce: nonce.raw) }
        case .failure(let error):
            appleNonce = nil
            // Closing the Apple sheet is a choice, not an error.
            if let error = error as? ASAuthorizationError, error.code == .canceled { return }
            errorMessage = String(localized: "Sign in with Apple didn't finish. Try again.")
        }
    }

    private func sendCode() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isPlausibleEmail(address) else { return }
        perform {
            try await auth.sendEmailCode(to: address)
            code = ""
            step = .code(sentTo: address)
        }
    }

    private func resendCode(_ address: String) {
        perform { try await auth.sendEmailCode(to: address) }
    }

    private func verifyCode(_ address: String) {
        let digits = code.filter(\.isNumber)
        guard Self.isPlausibleCode(digits) else { return }
        perform(failure: String(localized: "That code is wrong or has expired. Check it, or send a new one.")) {
            try await auth.verifyEmailCode(email: address, code: digits)
        }
    }

    /// Runs one sign-in request with the spinner up, turning a failure into
    /// a sentence. `failure` replaces the generic one for errors the server
    /// returned (a wrong code); being offline always says so.
    private func perform(failure: String? = nil, _ action: @escaping @MainActor () async throws -> Void) {
        KeyboardDismiss.resign()
        errorMessage = nil
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await action()
            } catch is URLError {
                errorMessage = String(localized: "You're offline. Connect to the internet and try again.")
            } catch {
                errorMessage = failure ?? String(localized: "Something went wrong signing in. Try again in a moment.")
            }
        }
    }

    static func isPlausibleEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !trimmed.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// Supabase codes are six digits by default and configurable up to ten.
    static func isPlausibleCode(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        return (6...10).contains(digits.count)
    }
}
