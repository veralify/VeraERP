import SwiftUI
import VeralifyCore

/// One circle on the board.
///
/// The label is inside the circle, which means it has to fit inside a shape
/// that narrows at the top and bottom: the text is sized from the diameter and
/// a circle too small to hold a word shows the amount alone rather than three
/// clipped letters.
struct BubbleCircle: View {
    let bubble: BubbleBoardView.Bubble
    let diameter: Double
    var isLifted = false
    var isTarget = false

    var body: some View {
        if bubble.isAdd { adder } else { filled }
    }

    /// An outline, not a fill: it is the one circle that is not money, and a
    /// solid one would read as another account with its label missing.
    private var adder: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .overlay(
                    Circle().strokeBorder(
                        Theme.lime.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 5])
                    )
                )

            Image(systemName: "plus")
                .font(.system(size: max(diameter * 0.34, 16), weight: .semibold))
                .foregroundStyle(Theme.lime)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(Text("Add"))
    }

    private var filled: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: diameter > 110 ? 5 : 2) {
                if diameter > 86 {
                    Image(systemName: icon)
                        .font(.system(size: diameter * 0.16, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.9))
                }

                if diameter > 64 {
                    Text(title)
                        .font(.system(size: max(diameter * 0.105, 9), weight: .bold))
                        .textCase(.uppercase)
                        .kerning(0.4)
                        .foregroundStyle(ink.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Text(CurrencyFormat.string(bubble.amount))
                    .font(.system(size: max(diameter * 0.13, 10), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, diameter * 0.16)
        }
        .frame(width: diameter, height: diameter)
        // The ring is the drop signal. Growing the target instead would move
        // every other circle out of the way mid-drag.
        .overlay(
            Circle().strokeBorder(.white, lineWidth: isTarget ? 3 : 0)
        )
        .scaleEffect(isLifted ? 1.08 : 1)
        .shadow(
            color: .black.opacity(isLifted ? 0.5 : 0.25),
            radius: isLifted ? 18 : 8,
            y: isLifted ? 10 : 4
        )
    }

    private var title: String {
        switch bubble {
        case .leftover:              String(localized: "Left over")
        case .expenses:              String(localized: "Expenses")
        case .add:                   ""
        case .debt(_, let name, _, _): name
        }
    }

    private var icon: String {
        switch bubble {
        case .leftover: "sparkles"
        case .expenses: "cart.fill"
        case .add:      "plus"
        case .debt:     "creditcard.fill"
        }
    }

    private var tint: Color {
        switch bubble {
        case .leftover: Theme.lime
        case .expenses: Theme.yellow
        case .add:      Theme.surface
        case .debt(_, _, _, let index):
            Theme.categorical[index % Theme.categorical.count]
        }
    }

    /// Every bubble colour in the set is a light, saturated tone, so the label
    /// is dark on all of them — including lime, where white would vanish.
    private var ink: Color { Theme.onAccent }
}
