import Foundation

/// The payoff plan as a spreadsheet.
///
/// Numbers go out unformatted — `1750.00`, not `€1,750.00`. A spreadsheet that
/// receives a currency symbol and thousands separators reads the column as text
/// and will not add it up, which defeats the point of exporting it.
public enum PlanExport {

    /// Column headings, in the order `row` writes them.
    public static let headers = [
        "Month", "Income", "Expenses", "Debt payment", "Interest",
        "Still owed", "Paid off", "Cash flow", "In hand", "Progress %", "Cleared"
    ]

    /// One CSV document for the whole plan.
    public static func csv(plan: PayoffPlan, steps: [JourneyStep]) -> String {
        var previous = plan.totalDebt
        var lines = [row(headers)]

        for step in steps {
            lines.append(
                row([
                    step.month,
                    number(plan.monthlyIncome),
                    number(plan.monthlyExpenses),
                    number(step.payment),
                    number(step.interest),
                    number(step.isFinish ? 0 : step.remainingDebt),
                    number(previous - step.remainingDebt),
                    number(plan.monthlyIncome - plan.monthlyExpenses - step.payment),
                    number(step.cumulativeBalance),
                    String(format: "%.1f", step.progress * 100),
                    step.clearedDebts.joined(separator: "; ")
                ])
            )
            previous = step.remainingDebt
        }

        return lines.joined(separator: "\n")
    }

    /// Plain decimal, two places, no grouping and no symbol.
    static func number(_ amount: Decimal) -> String {
        let rounded = Money.rounded(amount)
        return NSDecimalNumber(decimal: rounded)
            .description(withLocale: Locale(identifier: "en_US_POSIX"))
    }

    /// One CSV line, with anything awkward quoted.
    ///
    /// A debt called `Mum, personal loan` would otherwise split into two
    /// columns and shift every figure on that row one place left.
    static func row(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: ",")
    }

    static func escaped(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
