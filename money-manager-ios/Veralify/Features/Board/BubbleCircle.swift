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
            glass

            VStack(spacing: diameter > 110 ? 5 : 2) {
                if diameter > 86 {
                    Image(systemName: icon)
                        .font(.system(size: diameter * 0.16, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.92))
                }

                if diameter > 64 {
                    Text(title)
                        .font(.system(size: max(diameter * 0.105, 9), weight: .bold))
                        .textCase(.uppercase)
                        .kerning(0.4)
                        .foregroundStyle(ink.opacity(0.9))
                        .lineLimit(1)
                        // A long lender's name tightens before it shrinks,
                        // and only past both does it truncate.
                        .allowsTightening(true)
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

    /// A glass orb: the accent seen through a lens rather than painted flat.
    ///
    /// A translucent accent gradient keeps the colour (so a bubble is still
    /// read by hue at a glance), a bright specular arc top-left reads as light
    /// catching a curved surface, and a light-to-dark rim gives the edge its
    /// thickness. On iOS 26 the whole thing sits on real Liquid Glass, which
    /// adds the refraction and the live blur of what is behind it.
    @ViewBuilder
    private var glass: some View {
        let orb = ZStack {
            // Frost first, so there is something behind the colour to look
            // through. Without it a low-opacity tint over a near-black board
            // is just a dark disc.
            Circle().fill(.ultraThinMaterial)

            // Colour, held light: clear glass with a tint in it, not a painted
            // ball. The hue still has to carry identity across the board, so it
            // sits at the top of the range that still reads as transparent.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.34), tint.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // The specular: light gathering at the top-left of a sphere.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0)],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 0,
                        endRadius: diameter * 0.55
                    )
                )
                .blendMode(.softLight)

            // A tighter hot-spot so the light has a source, not just a wash.
            Ellipse()
                .fill(.white.opacity(0.4))
                .frame(width: diameter * 0.32, height: diameter * 0.2)
                .offset(x: -diameter * 0.16, y: -diameter * 0.24)
                .blur(radius: diameter * 0.06)
        }
        .overlay(
            // The rim: bright where the light hits, dark where it falls away.
            Circle().strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.75), tint.opacity(0.35), .white.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(diameter * 0.012, 1)
            )
        )
        .clipShape(.circle)

        if #available(iOS 26.0, *) {
            orb.glassEffect(.regular.tint(tint.opacity(0.28)), in: .circle)
        } else {
            orb
        }
    }

    private var title: String {
        switch bubble {
        case .leftover:              String(localized: "Left over")
        case .expenses:              String(localized: "Expenses")
        case .todo:                  String(localized: "To pay")
        case .add:                   ""
        case .debt(_, let name, _, _): name
        }
    }

    private var icon: String {
        switch bubble {
        case .leftover: "sparkles"
        case .expenses: "cart.fill"
        case .todo:     "checklist"
        case .add:      "plus"
        case .debt:     "creditcard.fill"
        }
    }

    private var tint: Color {
        switch bubble {
        case .leftover: Theme.lime
        case .expenses: Theme.yellow
        case .todo:     Theme.blue
        case .add:      Theme.surface
        case .debt(_, _, _, let index):
            Theme.categorical[index % Theme.categorical.count]
        }
    }

    /// Dark ink was right when the bubbles were solid, saturated fills. Clear
    /// glass over a near-black board is dark, so the label goes light and the
    /// hue is carried by the tint and the rim instead of by the text.
    private var ink: Color { .white }
}
