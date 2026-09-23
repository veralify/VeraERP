import SwiftUI

/// A fixed icon and colour for every category.
///
/// Fixed is the whole point. The category ring used to colour its slices by
/// rank — biggest first — so Food and Bills swapped colours the month one
/// overtook the other, and the chart looked like the data had moved when only
/// the order had. A colour follows the thing it names, everywhere it appears:
/// the ring, the list beneath it, the budget legend and the ledger rows.
enum CategoryStyle {

    /// Position in `EntryPresets.categories` decides the colour, so it is the
    /// same on every screen and stable as totals move.
    static func colour(_ category: String) -> Color {
        guard let index = EntryPresets.categories.firstIndex(of: category) else {
            return Theme.categoricalOther
        }
        return Theme.categorical(index)
    }

    static func icon(_ category: String) -> String {
        switch category {
        case "Tools":     "wrench.and.screwdriver.fill"
        case "Food":      "fork.knife"
        case "Transport": "car.fill"
        case "Bills":     "doc.text.fill"
        case "Shopping":  "bag.fill"
        case "Health":    "cross.case.fill"
        default:          "square.grid.2x2.fill"
        }
    }

    /// The circular badge the ledger and the category lists share.
    static func badge(_ category: String, size: CGFloat = 38) -> some View {
        let tint = colour(category)
        return Image(systemName: icon(category))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: .circle)
    }
}
