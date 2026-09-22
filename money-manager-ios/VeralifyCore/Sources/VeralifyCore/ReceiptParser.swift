import Foundation

/// A monetary total found on a receipt, and how much to trust it.
public struct ReceiptTotal: Hashable, Sendable {
    public enum Basis: Hashable, Sendable {
        /// Found on a line that names a total. Trustworthy.
        case keyword
        /// No total line was recognised, so the largest amount on the receipt
        /// was taken. Usually right, and always worth the user checking.
        case largestAmount
    }

    public let amount: Decimal
    public let basis: Basis
    /// The line it came from, so the UI can show its work.
    public let line: String

    public init(amount: Decimal, basis: Basis, line: String) {
        self.amount = amount
        self.basis = basis
        self.line = line
    }
}

/// Finds the total on a receipt that OCR has turned into lines of text.
///
/// Pure string handling with no Vision dependency, so the part most likely to
/// be wrong can be tested against real receipts without a camera or a
/// simulator.
public enum ReceiptParser {

    /// Lines that name a total, across the languages the app speaks.
    private static let totalKeywords = [
        "total", "totale", "tot.", "tot ",
        "amount due", "balance due", "importo", "da pagare", "a pagare",
        "المجموع", "الإجمالي", "اجمالي"
    ]

    /// Checked first, because every one of these *contains* a total keyword.
    /// "SUBTOTAL" matching "total" is the classic way to read back the figure
    /// before tax.
    private static let excludedKeywords = [
        "subtotal", "sub total", "sub-total", "sottototale", "subtotale",
        "imponibile", "taxable", "net total", "totale imponibile"
    ]

    /// The total, or nil when nothing on the receipt looks like money.
    ///
    /// Strategy, in order:
    /// 1. The **last** line naming a total. Receipts print subtotal, then tax,
    ///    then the total, so the last one is the one you pay.
    /// 2. Failing that, the largest amount anywhere — which on a receipt is
    ///    almost always the total, and is flagged as a guess.
    public static func findTotal(in lines: [String]) -> ReceiptTotal? {
        var keywordHit: ReceiptTotal?
        var largest: (amount: Decimal, line: String)?

        for line in lines {
            let lowered = line.lowercased()
            guard let largestOnLine = amounts(in: line).max() else { continue }

            if largest == nil || largestOnLine > largest!.amount {
                largest = (largestOnLine, line)
            }

            guard !excludedKeywords.contains(where: lowered.contains),
                  totalKeywords.contains(where: lowered.contains)
            else { continue }

            // Overwritten by any later total line: a receipt prints subtotal,
            // tax, then the figure you actually pay.
            keywordHit = ReceiptTotal(amount: largestOnLine, basis: .keyword, line: line)
        }

        return keywordHit
            ?? largest.map { ReceiptTotal(amount: $0.amount, basis: .largestAmount, line: $0.line) }
    }

    /// Every monetary amount on one line, in the order they appear.
    ///
    /// Handles both conventions, because a receipt from Milan prints `12,50`
    /// and one from Boston prints `12.50` — a parser that only knows the dot
    /// reads nothing at all off an Italian receipt.
    public static func amounts(in line: String) -> [Decimal] {
        var found: [Decimal] = []

        for match in line.matches(of: amountPattern) {
            let raw = String(match.output)
            guard let value = normalise(raw) else { continue }
            found.append(value)
        }
        return found
    }

    /// `1.234,56` · `1,234.56` · `12,50` · `12.50`.
    ///
    /// Computed rather than stored: `Regex` is not `Sendable`, so a static
    /// constant is a concurrency error under Swift 6.
    private static var amountPattern: Regex<Substring> {
        /(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}/
    }

    /// Turns a printed amount into a `Decimal` by reading the *last* separator
    /// as the decimal point and treating any earlier one as grouping.
    private static func normalise(_ raw: String) -> Decimal? {
        guard let lastSeparator = raw.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
        }

        let whole = raw[raw.startIndex..<lastSeparator]
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        let fraction = raw[raw.index(after: lastSeparator)...]

        return Decimal(string: "\(whole).\(fraction)", locale: Locale(identifier: "en_US_POSIX"))
    }
}
