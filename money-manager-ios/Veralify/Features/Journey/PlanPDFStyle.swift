import SwiftUI

/// How an exported plan looks on paper.
///
/// Ten of them because a payoff plan gets shown to different people for
/// different reasons — pinned to a fridge, filed, sent to a lender, argued over
/// with a partner — and those want genuinely different documents, not one
/// document in four colours.
enum PlanPDFStyle: String, CaseIterable, Identifiable, Hashable {
    case tracker, dashboard, report, timeline, plain
    case cards, charts, ledger, calendar, statement

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tracker:   "Tracker"
        case .dashboard: "Dashboard"
        case .report:    "Report"
        case .timeline:  "Timeline"
        case .plain:     "Plain"
        case .cards:     "Cards"
        case .charts:    "Charts"
        case .ledger:    "Ledger"
        case .calendar:  "Calendar"
        case .statement: "Statement"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .tracker:   "Boxes to tick as you pay. Made to print."
        case .dashboard: "Headline figures and both curves, on one page."
        case .report:    "Written up, with the charts that back it."
        case .timeline:  "The route as a road, milestone by milestone."
        case .plain:     "Just the figures, in one table."
        case .cards:     "A block per month, as the app shows them."
        case .charts:    "Nothing but the analytics, full width."
        case .ledger:    "Dense and small. Built for filing."
        case .calendar:  "The year at a glance, month by month."
        case .statement: "One section per debt, with its own schedule."
        }
    }

    /// Whether the layout draws its own analytics rather than a schedule.
    var isAnalytical: Bool {
        switch self {
        case .dashboard, .report, .charts: true
        default: false
        }
    }
}

/// The one colour an exported plan is allowed.
///
/// Print, not screen: these are darker and less saturated than the app's own
/// accents, which are chosen to glow on a black background and would come out
/// of a printer as pale mush.
enum PlanPDFAccent: String, CaseIterable, Identifiable, Hashable {
    case forest, ocean, plum, graphite, rust, indigo

    var id: String { rawValue }

    var colour: UIColor {
        switch self {
        case .forest:   UIColor(red: 0.07, green: 0.45, blue: 0.33, alpha: 1)
        case .ocean:    UIColor(red: 0.10, green: 0.33, blue: 0.62, alpha: 1)
        case .plum:     UIColor(red: 0.42, green: 0.17, blue: 0.47, alpha: 1)
        case .graphite: UIColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1)
        case .rust:     UIColor(red: 0.62, green: 0.27, blue: 0.11, alpha: 1)
        case .indigo:   UIColor(red: 0.24, green: 0.22, blue: 0.56, alpha: 1)
        }
    }

    /// The second series on a two-line chart. Separated from `colour` by
    /// lightness as well as hue, so the pair survives a monochrome printer.
    var secondary: UIColor {
        colour.withAlphaComponent(1).adjusted(brightness: 1.7, saturation: 0.55)
    }

    /// A wash of the same hue for panel fills.
    var wash: UIColor { colour.withAlphaComponent(0.07) }

    var swatch: Color { Color(colour) }
}

extension UIColor {
    func adjusted(brightness: CGFloat, saturation: CGFloat) -> UIColor {
        var hue: CGFloat = 0, sat: CGFloat = 0, bright: CGFloat = 0, alpha: CGFloat = 0
        guard getHue(&hue, saturation: &sat, brightness: &bright, alpha: &alpha) else { return self }
        return UIColor(
            hue: hue,
            saturation: min(sat * saturation, 1),
            brightness: min(bright * brightness, 1),
            alpha: alpha
        )
    }
}
