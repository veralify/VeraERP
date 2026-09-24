import Foundation

/// Money as the receipts contract carries it: a decimal string with a dot
/// (`"12.50"`), never a float.
///
/// Two directions. Reading, amounts arrive from the gateway already canonical
/// and are turned into `Decimal` exactly. Editing, the review screen accepts
/// whatever the user types over a figure — "1.234,50" from an Italian keyboard
/// habit, "£4.20" pasted from somewhere — and this reads it the same way the
/// gateway's `normaliseMoney` reads a model's answer (the shared cases in
/// `Fixtures/receipt_money_cases.json` hold the two together).
public enum ReceiptMoney {

    /// Digits after the decimal point for currencies that do not use two.
    private static let minorUnitOverrides: [String: Int] = [
        "BHD": 3, "CLP": 0, "ISK": 0, "JOD": 3, "JPY": 0, "KRW": 0,
        "KWD": 3, "OMR": 3, "TND": 3, "UGX": 0, "VND": 0
    ]

    public static func minorUnits(for currency: String?) -> Int {
        guard let currency else { return 2 }
        return minorUnitOverrides[currency.uppercased()] ?? 2
    }

    /// An exact decimal as digits and a scale, so nothing passes through a double.
    private struct Exact {
        var negative: Bool
        var digits: String
        var scale: Int
    }

    /// How to read a lone separator followed by exactly three digits ("1.234").
    /// Amounts are printed to the cent, so there it is grouping; a quantity
    /// ("1,234 kg") keeps it as a decimal point.
    private enum Mode { case money, decimal }

    private static func parseExact(_ input: String, mode: Mode) -> Exact? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2212}", with: "-")
        guard !text.isEmpty else { return nil }

        var negative = false
        if text.hasPrefix("("), text.hasSuffix(")"), text.count >= 2 {
            negative = true
            text = String(text.dropFirst().dropLast())
        }

        // Keep digits, separators and minus signs; currency signs and codes go.
        var kept = String(text.unicodeScalars.filter {
            ("0"..."9").contains($0) || $0 == "." || $0 == "," || $0 == "-"
        }.map(Character.init))
        if kept.hasPrefix("-") || kept.hasSuffix("-") { negative = true }
        while kept.hasPrefix("-") { kept.removeFirst() }
        while kept.hasSuffix("-") { kept.removeLast() }
        // A minus anywhere else ("12-05") means this was never an amount.
        guard kept.contains(where: \.isNumber), !kept.contains("-") else { return nil }

        let lastComma = kept.lastIndex(of: ",")
        let lastPeriod = kept.lastIndex(of: ".")
        var decimalMark: Character?
        if let lastComma, let lastPeriod {
            decimalMark = lastComma > lastPeriod ? "," : "."
        } else if lastComma != nil || lastPeriod != nil {
            let mark: Character = lastComma != nil ? "," : "."
            let parts = kept.split(separator: mark, omittingEmptySubsequences: false)
            if parts.count > 2 {
                decimalMark = nil
            } else {
                let whole = parts[0], fraction = parts[1]
                let looksGrouped = mode == .money
                    && fraction.count == 3
                    && (1...3).contains(whole.count)
                    && whole.first != "0"
                decimalMark = looksGrouped ? nil : mark
            }
        }

        var whole = kept
        var fraction = ""
        if let decimalMark, let at = kept.lastIndex(of: decimalMark) {
            whole = String(kept[..<at])
            fraction = String(kept[kept.index(after: at)...])
        }
        // Grouping marks only ever separate thousands, so "1,2,3.45" is a
        // misread, not 123.45.
        let groups = whole.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "." || $0 == "," })
        if groups.count > 1 {
            guard (1...3).contains(groups[0].count), groups.dropFirst().allSatisfy({ $0.count == 3 })
            else { return nil }
        }
        whole = groups.joined()
        guard !fraction.contains(where: { $0 == "." || $0 == "," }) else { return nil }
        let digits = (whole.isEmpty ? "0" : whole) + fraction
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Exact(negative: negative, digits: digits, scale: fraction.count)
    }

    /// Rounds half away from zero, the way tills round, working on digits.
    private static func rescale(_ value: Exact, to scale: Int) -> Exact {
        if value.scale == scale { return value }
        if value.scale < scale {
            return Exact(
                negative: value.negative,
                digits: value.digits + String(repeating: "0", count: scale - value.scale),
                scale: scale
            )
        }
        let drop = value.scale - scale
        var kept = Array(value.digits.dropLast(drop))
        let firstDropped = value.digits.dropFirst(value.digits.count - drop).first ?? "0"
        if kept.isEmpty { kept = ["0"] }
        if let digit = firstDropped.wholeNumberValue, digit >= 5 {
            // Carry through the kept digits.
            var index = kept.count - 1
            var carry = true
            while carry && index >= 0 {
                if kept[index] == "9" {
                    kept[index] = "0"
                    index -= 1
                } else {
                    kept[index] = Character(String((kept[index].wholeNumberValue ?? 0) + 1))
                    carry = false
                }
            }
            if carry { kept.insert("1", at: 0) }
        }
        return Exact(negative: value.negative, digits: String(kept), scale: scale)
    }

    private static func format(_ value: Exact) -> String {
        var digits = value.digits
        while digits.count > value.scale + 1, digits.first == "0" { digits.removeFirst() }
        if digits.count < value.scale + 1 {
            digits = String(repeating: "0", count: value.scale + 1 - digits.count) + digits
        }
        var body = digits
        if value.scale > 0 {
            body.insert(".", at: body.index(body.endIndex, offsetBy: -value.scale))
        }
        let isZero = !body.contains { $0 != "0" && $0 != "." }
        return value.negative && !isZero ? "-" + body : body
    }

    /// The canonical contract string for a typed or printed amount, in the
    /// currency's precision: `"1.234,5"` → `"1234.50"`, `"2,00-"` → `"-2.00"`.
    public static func canonical(_ text: String, currency: String? = nil) -> String? {
        guard let exact = parseExact(text, mode: .money) else { return nil }
        return format(rescale(exact, to: minorUnits(for: currency)))
    }

    /// A plain decimal with trailing zeros removed, for quantities and tax
    /// rates: `"22,00 %"` → `"22"`.
    public static func canonicalDecimal(_ text: String) -> String? {
        guard var exact = parseExact(text, mode: .decimal) else { return nil }
        while exact.scale > 0, exact.digits.hasSuffix("0") {
            exact.digits.removeLast()
            exact.scale -= 1
        }
        return format(exact)
    }

    /// A lenient read of a typed amount, as `Decimal`.
    public static func parse(_ text: String, currency: String? = nil) -> Decimal? {
        canonical(text, currency: currency).flatMap(decimal(fromCanonical:))
    }

    /// Exact conversion of a contract string (`"-12.50"`). Nil for anything
    /// else — a canonical string that is not canonical is a bug to surface,
    /// not to guess around.
    public static func decimal(fromCanonical text: String) -> Decimal? {
        guard text.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The contract string for an amount: `12.5` → `"12.50"`.
    public static func string(_ amount: Decimal, currency: String? = nil) -> String {
        let scale = minorUnits(for: currency)
        var input = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, scale, .plain)
        let negative = rounded < 0
        let magnitude = negative ? -rounded : rounded
        // Shifting by the scale leaves a whole number, whose description is
        // plain digits with no exponent or grouping.
        var shifted = magnitude
        var scaled = Decimal()
        _ = NSDecimalMultiplyByPowerOf10(&scaled, &shifted, Int16(scale), .plain)
        let digits = NSDecimalNumber(decimal: scaled).stringValue
        return format(Exact(negative: negative, digits: digits, scale: scale))
    }
}
