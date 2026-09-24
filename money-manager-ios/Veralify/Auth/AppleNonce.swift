import CryptoKit
import Foundation

/// The nonce for Sign in with Apple.
///
/// Apple puts the SHA-256 of the nonce the app sends into the identity token;
/// Supabase is given the raw value, hashes it and compares. A token captured
/// in transit is therefore useless without the raw nonce, which never leaves
/// the phone except in that one request.
struct AppleNonce: Equatable {
    let raw: String

    var sha256: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// 32 characters from a URL-safe alphabet, drawn from the system's
    /// cryptographically secure generator.
    static func make(length: Int = 32) -> AppleNonce {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        let raw = String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
        return AppleNonce(raw: raw)
    }
}
