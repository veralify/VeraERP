import Foundation

/// The normalised merchant name that category rules, duplicate warnings and
/// reports key on.
///
/// Defined in docs/RECEIPTS_CONTRACTS.md §4 and implemented twice: here, and
/// in TypeScript in the AI gateway (`merchant-key.ts`), which files a receipt
/// using the rules this app writes. Both are tested against the same table
/// (`Fixtures/merchant_keys.json`), because a rule saved under one spelling
/// of the key and looked up under another is a correction the app silently
/// forgets.
public enum MerchantKey {

    /// Legal-form suffixes dropped from the end of the name, as token runs.
    static let legalSuffixes: [[String]] = [
        ["srl"], ["s", "r", "l"],
        ["spa"], ["s", "p", "a"],
        ["snc"], ["sas"],
        ["ltd"], ["limited"], ["plc"], ["llp"],
        ["inc"], ["llc"], ["gmbh"]
    ]

    /// `"ESSELUNGA S.p.A."` → `"esselunga"`, `"Marks & Spencer PLC"` → `"marks and spencer"`.
    ///
    /// Works on Unicode scalars and their general category rather than on
    /// `Character.isLetter`, so it agrees with the gateway's `\p{L}\p{N}` to
    /// the scalar. "Alphanumeric" includes non-Latin letters: an ASCII-only key
    /// would turn every Arabic merchant name into the same empty string.
    public static func make(from name: String) -> String {
        let decomposed = name.lowercased().decomposedStringWithCompatibilityMapping

        var tokens: [String] = []
        var current = String.UnicodeScalarView()
        func endToken() {
            if !current.isEmpty {
                tokens.append(String(current))
                current = String.UnicodeScalarView()
            }
        }

        for scalar in decomposed.unicodeScalars {
            if isMark(scalar) { continue }
            if scalar == "&" {
                endToken()
                tokens.append("and")
            } else if isAlphanumeric(scalar) {
                current.append(scalar)
            } else {
                endToken()
            }
        }
        endToken()

        // Repeated, because a name can carry two ("Foo Ltd Inc"), but never
        // down to nothing: a business literally called "SPA" keeps its name.
        var stripped = true
        while stripped {
            stripped = false
            for suffix in legalSuffixes
            where tokens.count > suffix.count && Array(tokens.suffix(suffix.count)) == suffix {
                tokens.removeLast(suffix.count)
                stripped = true
                break
            }
        }
        return tokens.joined(separator: " ")
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }

    private static func isAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }
}
