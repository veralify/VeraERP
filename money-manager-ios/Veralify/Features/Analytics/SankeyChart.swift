import SwiftUI
import VeralifyCore

/// A two-column Sankey, matching the web cashflow widget.
///
/// Geometry comes from `SankeyLayout`; this view only draws it and places the
/// labels. Flow reads left-to-right even under right-to-left layout, which is
/// the convention the web widget uses and how flow diagrams are read generally.
struct SankeyChart: View {
    struct Node: Identifiable {
        let id: String
        let label: String
        let color: Color
    }

    let sources: [Node]
    let targets: [Node]
    let flows: [SankeyLayout.Flow]

    private let barWidth: CGFloat = 13
    private let labelWidth: CGFloat = 96
    private let labelGap: CGFloat = 12

    private var layout: SankeyLayout.Result {
        // A generous gap keeps the ribbons visually separate, as in the web
        // widget, rather than fusing into one band.
        SankeyLayout.compute(flows: flows, gap: 0.14)
    }

    var body: some View {
        GeometryReader { geometry in
            let result = layout
            let size = geometry.size
            let sourceBarX = labelWidth
            let targetBarX = size.width - labelWidth - barWidth

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawRibbons(
                        context: context,
                        result: result,
                        size: size,
                        sourceInner: sourceBarX + barWidth,
                        targetInner: targetBarX
                    )
                    drawBars(context: context, bands: result.sources, nodes: sources, x: sourceBarX, size: size)
                    drawBars(context: context, bands: result.targets, nodes: targets, x: targetBarX, size: size)
                }

                labels(for: result.sources, nodes: sources, size: size, onRight: false)
                labels(for: result.targets, nodes: targets, size: size, onRight: true)
            }
            // `Canvas` draws in raw coordinates, but `.position()` is mirrored
            // under right-to-left layout — so bars and labels would land on
            // opposite sides. Pinning this subtree to left-to-right makes the
            // two agree. Arabic text inside each label still shapes correctly.
            .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement()
        .accessibilityLabel("Money flow diagram")
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: - Drawing

    private func drawRibbons(
        context: GraphicsContext,
        result: SankeyLayout.Result,
        size: CGSize,
        sourceInner: CGFloat,
        targetInner: CGFloat
    ) {
        for ribbon in result.ribbons {
            let sourceTop = ribbon.sourceStart * size.height
            let sourceBottom = ribbon.sourceEnd * size.height
            let targetTop = ribbon.targetStart * size.height
            let targetBottom = ribbon.targetEnd * size.height
            // Control points two-thirds of the way out give the deep S-curve of
            // the reference rather than a lazy diagonal.
            let span = targetInner - sourceInner
            let c1 = sourceInner + span * 0.5
            let c2 = targetInner - span * 0.5

            var path = Path()
            path.move(to: CGPoint(x: sourceInner, y: sourceTop))
            path.addCurve(
                to: CGPoint(x: targetInner, y: targetTop),
                control1: CGPoint(x: c1, y: sourceTop),
                control2: CGPoint(x: c2, y: targetTop)
            )
            path.addLine(to: CGPoint(x: targetInner, y: targetBottom))
            path.addCurve(
                to: CGPoint(x: sourceInner, y: sourceBottom),
                control1: CGPoint(x: c2, y: targetBottom),
                control2: CGPoint(x: c1, y: sourceBottom)
            )
            path.closeSubpath()

            // A ribbon carries its destination's colour, dimmed so the solid
            // node bars stay the brightest thing on the chart.
            context.fill(path, with: .color(color(for: ribbon.target, in: targets).opacity(0.5)))
        }
    }

    private func drawBars(
        context: GraphicsContext,
        bands: [SankeyLayout.Band],
        nodes: [Node],
        x: CGFloat,
        size: CGSize
    ) {
        for band in bands {
            let rect = CGRect(
                x: x,
                y: band.start * size.height,
                width: barWidth,
                // Keep a hairline visible for a node that rounds to nothing.
                height: max(3, band.height * size.height)
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2),
                with: .color(color(for: band.id, in: nodes))
            )
        }
    }

    // MARK: - Labels

    private func labels(
        for bands: [SankeyLayout.Band],
        nodes: [Node],
        size: CGSize,
        onRight: Bool
    ) -> some View {
        ForEach(bands) { band in
            Text(nodes.first { $0.id == band.id }?.label ?? band.id)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(onRight ? .leading : .trailing)
                .frame(width: labelWidth - labelGap, alignment: onRight ? .leading : .trailing)
                .position(
                    x: onRight
                        ? size.width - (labelWidth - labelGap) / 2
                        : (labelWidth - labelGap) / 2,
                    y: (band.start + band.height / 2) * size.height
                )
        }
    }

    private func color(for id: String, in nodes: [Node]) -> Color {
        nodes.first { $0.id == id }?.color ?? Theme.textTertiary
    }

    private var accessibilitySummary: String {
        // A drawing is invisible to VoiceOver, so state the flows in words.
        layout.targets
            .map { band in
                let label = targets.first { $0.id == band.id }?.label ?? band.id
                return "\(label) \(CurrencyFormat.string(band.value))"
            }
            .joined(separator: String(localized: ", "))
    }
}

/// The Sankey's own card: a centred total above the diagram, as in the web
/// widget, instead of the left-aligned title the other charts use.
struct SankeyCard: View {
    let total: Decimal
    let caption: LocalizedStringKey
    let sources: [SankeyChart.Node]
    let targets: [SankeyChart.Node]
    let flows: [SankeyLayout.Flow]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text(CurrencyFormat.string(total))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            SankeyChart(sources: sources, targets: targets, flows: flows)
                .frame(height: max(260, CGFloat(targets.count) * 76))
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}
