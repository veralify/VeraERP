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

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The welcome screen is a cover, not a step, so it is excluded from the
    /// progress count.
    static var progressSteps: [OnboardingStep] { [.income, .expenses, .debts, .target, .summary] }

    var progressIndex: Int? { Self.progressSteps.firstIndex(of: self) }
}

/// Parses a typed amount without trusting the device's decimal separator.
///
/// The keypad offers whichever separator the locale uses, and Arabic locales
/// may supply Arabic-Indic digits, so both are normalised before parsing.
/// Returns nil for anything that is not a usable positive amount.
enum DayParser {
    /// A day-of-month, or nil when the value is empty or outside 1...31.
    static func parse(_ text: String) -> Int? {
        guard let value = AmountParser.parse(text) else { return nil }
        let day = (value as NSDecimalNumber).intValue
        return (1...31).contains(day) ? day : nil
    }
}

enum AmountParser {
    static func parse(_ text: String) -> Decimal? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "٬", with: "")
            .applyingTransform(.toLatin, reverse: false) ?? text

        guard !normalized.isEmpty,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value >= 0
        else { return nil }
        return value
    }
}
