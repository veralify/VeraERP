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

    /// The badge the ledger and the category lists share: the category's
    /// glyph on a soft wash of its colour, in a rounded square.
    ///
    /// The glyph is the category colour pulled a third of the way toward the
    /// primary text colour. The raw categorical hues are chosen for charts, and
    /// the light yellow or pink alone would be too faint as a glyph on its own
    /// wash; mixing toward the text colour darkens them on paper and lightens
    /// them on ink, so the glyph clears 3:1 in both appearances.
    static func badge(_ category: String, size: CGFloat = Theme.Icon.rowBadge) -> some View {
        let tint = colour(category)
        return Image(systemName: icon(category))
            .font(.system(size: size * 0.44, weight: Theme.Icon.badgeWeight))
            .foregroundStyle(tint.mix(with: Theme.textPrimary, by: 0.35))
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}
