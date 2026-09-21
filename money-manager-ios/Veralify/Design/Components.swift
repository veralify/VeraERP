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
                Spacer(minLength: 8)
                Text(progressLabel)
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
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
        HStack {
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

    private let tabs: [(icon: String, label: LocalizedStringKey)] = [
        ("house.fill", "Home"),
        ("map.fill", "Roadmap"),
        ("list.bullet.rectangle.fill", "Entries"),
        ("person.2.fill", "Family")
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
        .padding(.vertical, 8)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
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
                }
            }
            .foregroundStyle(isActionActive ? Theme.textPrimary : Theme.onAccent)
            .frame(height: 40)
            .padding(.horizontal, isActionActive ? 14 : 16)
            .background(isActionActive ? Theme.surfaceElevated : Theme.lime, in: .capsule)
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, 2)
        .animation(.bouncy(duration: 0.34), value: isActionActive)
        .accessibilityLabel(isActionActive ? "Close" : actionTitle)
    }

    private func tabButton(index: Int) -> some View {
        Button {
            selection = index
        } label: {
            Image(systemName: tabs[index].icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(selection == index ? Theme.textPrimary : Theme.textTertiary)
                .symbolEffect(.bounce, value: selection == index)
                .frame(width: 46, height: 40)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tabs[index].label)
    }
}
