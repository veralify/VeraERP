import Foundation

extension String {
    /// Converts an ISO 3166-1 alpha-2 country code to its flag emoji (e.g. "US" → "🇺🇸")
    func toFlagEmoji() -> String {
        self.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }.map { String($0) }.joined()
    }
}
