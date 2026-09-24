import Foundation

/// In-flight onboarding entries.
///
/// Onboarding builds plain drafts and commits them once at the end, so
/// abandoning the flow leaves no half-built store behind.
struct DraftEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var amount: Decimal
}

struct DraftDebt: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var balance: Decimal
    var apr: Decimal
    var minimumPayment: Decimal
    /// Day of month the payment falls due. Without it nothing can be alerted on.
    var dueDay: Int?
}

/// The steps of the first-run flow, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case income
    case expenses
    case debts
    case target
    case summary
    /// Celebration after the data is committed. A cover, like `welcome`, so it
    /// is excluded from the step count.
    case success

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The welcome screen is a cover, not a step, so it is excluded from the
    /// progress count.
    static var progressSteps: [OnboardingStep] { [.income, .expenses, .debts, .target, .summary] }

    var progressIndex: Int? { Self.progressSteps.firstIndex(of: self) }
}

/// Parses a day-of-month typed into a numeric field.
enum DayParser {
    /// A day-of-month, or nil when the value is empty or outside 1...31.
    static func parse(_ text: String) -> Int? {
        guard let value = AmountParser.parse(text) else { return nil }
        let day = (value as NSDecimalNumber).intValue
        return (1...31).contains(day) ? day : nil
    }
}

/// Parses a typed amount without trusting the device's decimal separator.
///
/// The keypad offers whichever separator the locale uses, and Arabic locales
/// may supply Arabic-Indic digits, so both are normalised before parsing.
/// Returns nil for anything that is not a usable non-negative amount.
///
/// The whole string has to be a number. `Decimal(string:)` alone accepts a
/// numeric prefix, so "12abc" became 12, "1e3" became 1000, and a pasted
/// "1,250.00" became 1.25 — a thousandfold error in a balance.
enum AmountParser {
    static func parse(_ text: String) -> Decimal? {
        let latin = text.applyingTransform(.toLatin, reverse: false) ?? text
        var digits = latin
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: "٬", with: "")
            .filter { !$0.isWhitespace && $0 != "'" }

        // With both marks present, whichever comes last is the decimal point
        // ("1,250.00" and "1.250,00"). With only one, a single occurrence is a
        // decimal ("19,9"), several are grouping ("1.250.000").
        let lastComma = digits.lastIndex(of: ",")
        let lastPeriod = digits.lastIndex(of: ".")
        var grouping: Character?
        if let lastComma, let lastPeriod {
            grouping = lastComma > lastPeriod ? "." : ","
        } else {
            grouping = ([",", "."] as [Character]).first { mark in
                digits.filter { $0 == mark }.count > 1
            }
        }
        if let grouping {
            // Grouping marks only ever separate thousands, so "3.5.1" is a typo,
            // not 351.
            let decimalMark: Character = grouping == "," ? "." : ","
            let whole = digits.split(separator: decimalMark, omittingEmptySubsequences: false)[0]
            let groups = whole.split(separator: grouping, omittingEmptySubsequences: false)
            guard (1...3).contains(groups[0].count),
                  groups.dropFirst().allSatisfy({ $0.count == 3 })
            else { return nil }
            digits.removeAll { $0 == grouping }
        }
        digits = digits.replacingOccurrences(of: ",", with: ".")

        guard digits.contains(where: \.isNumber),
              digits.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              digits.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX")),
              value >= 0
        else { return nil }
        return value
    }
}
