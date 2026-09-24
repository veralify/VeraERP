import SwiftUI

/// Currency formatting.
///
/// The web app renders EUR with en-US grouping (`€1,750.00`), so the port
/// matches that rather than the device locale — otherwise the same figure reads
/// differently on the two surfaces.
enum CurrencyFormat {
    /// Amounts render in the currency the user picked, but always with en_US
    /// separators. The app's own text fields parse and re-emit numbers in that
    /// form, so letting the separators follow the display language would make a
    /// figure read back differently from how it was typed.
    static func string(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: AppSettings.currencyCode)
                .locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(2))
        )
    }

    /// Just the symbol, for a row that puts it beside an editable number
    /// rather than inside a formatted one.
    static var symbol: String {
        (Locale(identifier: "en_US") as NSLocale)
            .displayName(forKey: .currencySymbol, value: AppSettings.currencyCode)
            ?? AppSettings.currencyCode
    }
}

extension Decimal {
    /// Percentage text that matches the currency formatting's separators, so a
    /// rate and an amount on the same row do not disagree about decimal marks.
    var percentText: String {
        formatted(
            .number
                .locale(Locale(identifier: "en_US"))
                .precision(.fractionLength(0...2))
        )
    }
}

/// Capsule badge. The signature element of the reference design.
struct Pill: View {
    enum Style {
        /// Solid vivid fill with near-black text — for emphasis.
        case accent(Color)
        /// Dark fill with a coloured status dot — for quieter state.
        case muted(dot: Color?)
        /// Outlined, for a value that is informative rather than a status.
        case outlined(Color)
    }

    let text: String
    var style: Style = .muted(dot: nil)

    var body: some View {
        HStack(spacing: 6) {
            if case .muted(let dot) = style, let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
            }
            Text(text)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                // A capsule cannot hold two lines: squeezed in a row on a small
                // phone, the text wrapped and the pill turned into a lozenge.
                // Shrink a touch first, then truncate, and stay one line.
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(foreground)
        .background(background, in: .capsule)
        .overlay {
            if case .outlined(let color) = style {
                Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1)
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .accent(let color): color.readableForeground
        case .muted: Theme.textPrimary
        case .outlined(let color): color
        }
    }

    private var background: Color {
        switch style {
        case .accent(let color): color
        case .muted: Theme.surfaceElevated
        case .outlined: .clear
        }
    }
}

/// The vivid hero card: one figure that matters, on a fill whose colour states
/// whether that figure is good news.
struct AccentCard: View {
    let eyebrow: LocalizedStringKey
    let amount: Decimal
    let caption: LocalizedStringKey
    /// 0...1 — drives the inline progress bar.
    let progress: Double
    let progressLabel: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.8))
                Text(CurrencyFormat.string(amount))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(foreground)
            }

            ProgressTrack(progress: progress, foreground: foreground)

            HStack {
                Text(caption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                // The figure keeps its full width; the caption beside it is
                // the one that wraps when the row runs short.
                Text(progressLabel)
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white, in: .capsule)
                    .accessibilityLabel(Text(progressLabel))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color { accent.readableForeground
    }
}

/// Thin progress bar drawn inside an accent card. Uses `.leading`, so it fills
/// from the right under right-to-left layout without extra work.
struct ProgressTrack: View {
    let progress: Double
    var foreground: Color = Theme.onAccent
    /// White reads as the brightest thing on an accent card; on a dark surface
    /// it does not, so the caller can pick the accent instead.
    var fill: Color = .white

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track darkens (or lightens) the accent; the fill is always
                // white, as in the reference — on a light accent that reads as
                // the brightest thing on the card.
                Capsule().fill(foreground.opacity(0.25))
                // The 6pt floor keeps a sliver visible at 1%, but at 0% it
                // left a stray dot on an otherwise empty track.
                Capsule()
                    .fill(fill)
                    .frame(
                        width: progress <= 0
                            ? 0
                            : max(6, geometry.size.width * progress.clamped())
                    )
            }
        }
        .frame(height: 6)
    }
}

private extension Double {
    func clamped() -> Double { Swift.min(Swift.max(self, 0), 1) }
}

/// Section header: a title with an optional trailing action, matching the
/// "Total Tasks: 4 / + Add" row in the reference.
struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        // Baseline rather than centre: the trailing slot is usually smaller
        // text (a count, "All entries"), which centred sat visibly low.
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// A row inside a grouped dark card: title, supporting copy, then a status line.
struct DetailRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let value: String
    let statusText: String
    let statusDot: Color
    let tag: String
    let tagColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Pill(text: statusText, style: .muted(dot: statusDot))
                Pill(text: tag, style: .accent(tagColor))
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

/// Groups rows into one dark card with hairline dividers, as the reference does
/// for its task list.
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
    }
}

/// Floating navigation: one capsule holding the destinations with the accent
/// action inline, between them.
struct FloatingTabBar: View {
    @Binding var selection: Int
    let actionTitle: LocalizedStringKey
    /// When the action has opened something, it turns into a dismiss.
    var isActionActive: Bool = false
    let onAction: () -> Void

    /// A tab's mark. Most are SF Symbols; the board draws its own, because no
    /// symbol is three circles of three different sizes and the equal-dot
    /// clusters that come close read as a grid rather than as the board.
    enum TabIcon {
        case system(String)
        case bubbles
    }

    private let tabs: [(icon: TabIcon, label: LocalizedStringKey)] = [
        (.system("house.fill"), "Today"),
        (.bubbles, "Board"),
        (.system("person.2.fill"), "Split"),
        (.system("wallet.pass.fill"), "Wallet")
    ]
    /// Destinations before the action; the rest sit after it. Two either side
    /// keeps the accent button centred.
    private let actionIndex = 2

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<actionIndex, id: \.self) { tabButton(index: $0) }
            actionButton
            ForEach(actionIndex..<tabs.count, id: \.self) { tabButton(index: $0) }
        }
        .padding(.horizontal, 8)
        // 6 rather than 8: the buttons inside are now 44pt tall to meet the
        // minimum touch target, so the capsule keeps its 56pt height.
        .padding(.vertical, 6)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        // Only the action's label scales with text size — the tab glyphs are
        // fixed. Unbounded, it pushed the capsule wider than a small phone at
        // accessibility sizes; the system tab bar stops growing too.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var actionButton: some View {
        Button(action: onAction) {
            Group {
                if isActionActive {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                } else {
                    Label(actionTitle, systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isActionActive ? Theme.textPrimary : Theme.onAccent)
            .frame(height: 40)
            .padding(.horizontal, isActionActive ? 14 : 16)
            .background(isActionActive ? Theme.surfaceElevated : Theme.lime, in: .capsule)
            // The capsule stays 40pt; the clear band around it brings the
            // target to 44.
            .padding(.vertical, 2)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, 2)
        .animation(.bouncy(duration: 0.34), value: isActionActive)
        .accessibilityLabel(isActionActive ? "Close" : actionTitle)
    }

    private func tabButton(index: Int) -> some View {
        let isSelected = selection == index

        return Button {
            selection = index
        } label: {
            Group {
                switch tabs[index].icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 17, weight: .medium))
                        .symbolEffect(.bounce, value: isSelected)
                case .bubbles:
                    BubblesMark()
                        .frame(width: 20, height: 20)
                        .scaleEffect(isSelected ? 1.12 : 1)
                        .animation(.bouncy(duration: 0.4), value: isSelected)
                }
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
            .frame(width: 46, height: 44)
            // Without this only the glyph itself took the tap, and the clear
            // space around it — most of the button — fell through.
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tabs[index].label)
    }
}

/// Three circles at three sizes, laid out the way the board lays out money:
/// one large, one medium, one small, with air between them.
///
/// The gaps are the whole mark. Circles that touch merge into one silhouette
/// at 20pt and the icon reads as a blob, so the radii are set to leave a clear
/// margin between every pair rather than to fill the box.
struct BubblesMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            // Radii and centres as fractions of the box, so the mark scales
            // with the type around it.
            let circles: [(x: Double, y: Double, r: Double)] = [
                (0.30, 0.37, 0.27),
                (0.81, 0.21, 0.16),
                (0.75, 0.77, 0.20)
            ]

            for circle in circles {
                let radius = circle.r * unit
                let rect = CGRect(
                    x: circle.x * unit - radius,
                    y: circle.y * unit - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .style(.foreground))
            }
        }
        .accessibilityHidden(true)
    }
}
