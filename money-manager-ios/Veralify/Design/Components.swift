import SwiftUI

// MARK: - Money formatting

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

    /// A figure ready for display: the sign the design system asks for, a
    /// true minus (U+2212) rather than a hyphen, and wrapped in a
    /// left-to-right isolate so `−€1,750.00` keeps its shape inside Arabic
    /// text instead of the minus drifting to the far side of the number.
    static func display(_ amount: Decimal, sign: MoneySign = .automatic) -> String {
        let magnitude = string(amount < 0 ? -amount : amount)
        let prefix: String
        switch sign {
        case .automatic: prefix = amount < 0 ? "\u{2212}" : ""
        case .always:    prefix = amount > 0 ? "+" : (amount < 0 ? "\u{2212}" : "")
        case .never:     prefix = ""
        }
        return "\u{2066}" + prefix + magnitude + "\u{2069}"
    }
}

/// How a figure shows its sign.
enum MoneySign: Sendable, Hashable {
    /// Negative figures get "−"; positive ones get nothing. Balances, totals.
    case automatic
    /// "+" and "−" both shown. Flows (a ledger row) and changes (a delta).
    case always
    /// Magnitude only — the direction is stated another way (a column titled
    /// "Money out", a debt balance).
    case never
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

/// The one way to put money on screen.
///
/// Tabular digits, a true minus, RTL-safe, Dynamic Type, a numeric content
/// transition when the value changes, and colour only when the sign is news.
///
///     MoneyText(summary.leftThisMonth, size: .hero)
///     MoneyText(record.signedAmount, tone: .signed, sign: .always)
struct MoneyText: View {
    enum Size: Sendable, Hashable {
        /// The screen's headline figure. Serif, 44pt at the default size.
        case hero
        /// Stat tiles, metric cards. Serif.
        case large
        /// Payment cards, secondary headline figures. Serif.
        case medium
        /// List-row amounts. Sans.
        case body
        /// Supporting amounts inside rows and key–value lines. Sans.
        case small
        /// Badges and footnotes. Sans.
        case caption
    }

    enum Tone: Sendable, Hashable {
        /// Balances, totals, debts owed: the figure is the news, not its sign.
        case neutral
        /// Quieter repeated figures (a subtotal beside a header).
        case secondary
        /// Green when positive, red when negative, neutral at zero.
        case signed
        /// Always success colour (money in).
        case positive
        /// Always danger colour (money out).
        case negative
        /// On a strong accent/semantic fill.
        case onAccent
    }

    let amount: Decimal
    var size: Size
    var tone: Tone
    var sign: MoneySign

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    init(_ amount: Decimal, size: Size = .body, tone: Tone = .neutral, sign: MoneySign = .automatic) {
        self.amount = amount
        self.size = size
        self.tone = tone
        self.sign = sign
    }

    var body: some View {
        Text(CurrencyFormat.display(amount, sign: sign))
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(size == .hero ? 0.5 : 0.7)
            .contentTransition(.numericText(value: amount.chartValue))
    }

    private var font: Font {
        switch size {
        case .hero:    .system(size: heroSize, weight: .semibold, design: .serif).monospacedDigit()
        case .large:   Theme.Typography.figureLarge
        case .medium:  Theme.Typography.figure
        case .body:    Theme.Typography.amount
        case .small:   Theme.Typography.amountSmall
        case .caption: Theme.Typography.amountCaption
        }
    }

    private var color: Color {
        switch tone {
        case .neutral:   Theme.textPrimary
        case .secondary: Theme.textSecondary
        case .signed:    Theme.moneyColor(amount)
        case .positive:  Theme.success
        case .negative:  Theme.danger
        case .onAccent:  Theme.onAccent
        }
    }
}

// MARK: - Surfaces

/// The standard card: surface fill, hairline border, continuous corners.
struct CardSurface: ViewModifier {
    var padding: CGFloat?
    var radius: CGFloat
    var fill: Color

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: Theme.Border.hairline)
            }
    }
}

extension View {
    /// Wraps content as a card. `padding: nil` for content that pads itself
    /// (a grouped list).
    func surfaceCard(
        padding: CGFloat? = Theme.Spacing.cardPadding,
        radius: CGFloat = Theme.Radius.card,
        fill: Color = Theme.surface
    ) -> some View {
        modifier(CardSurface(padding: padding, radius: radius, fill: fill))
    }

    /// A shadow for things that float over content. Content itself is flat.
    func elevation(_ level: Theme.Elevation) -> some View {
        shadow(color: level == .flat ? .clear : Theme.shadow, radius: level.radius, x: 0, y: level.y)
    }

    /// The canvas behind a whole screen, under the safe areas.
    func screenBackground() -> some View {
        background { Theme.canvas.ignoresSafeArea() }
    }

    /// Navigation bar that sits on the canvas colour.
    func themedNavigationBar() -> some View {
        toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// Every sheet: canvas background, the sheet radius, a drag indicator.
    func sheetChrome() -> some View {
        presentationBackground(Theme.canvas)
            .presentationCornerRadius(Theme.Radius.sheet)
            .presentationDragIndicator(.visible)
    }
}

/// A plain card around arbitrary content.
struct Card<Content: View>: View {
    var padding: CGFloat
    var content: Content

    init(padding: CGFloat = Theme.Spacing.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            content
        }
        .surfaceCard(padding: padding)
    }
}

/// Groups rows into one card with hairline dividers between them. Put
/// `RowDivider()` between rows yourself.
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .surfaceCard(padding: nil)
    }
}

/// Hairline between rows. `inset` lines it up with the row's text when the
/// row has a leading icon (`Theme.Icon.rowBadge + Theme.Spacing.rowIconGap`).
struct RowDivider: View {
    var inset: CGFloat

    @Environment(\.displayScale) private var displayScale

    init(inset: CGFloat = 0) {
        self.inset = inset
    }

    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1 / max(displayScale, 1))
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

// MARK: - Hero

/// Tinted wash shared by the hero cards: the tone's colour laid over the card
/// surface, so it reads as calm in both appearances.
private struct HeroBackground: View {
    let wash: Color
    let edge: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
            .fill(Theme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .fill(wash)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .strokeBorder(edge, lineWidth: Theme.Border.hairline)
            }
    }
}

/// The one card per screen that holds the figure the screen is about. Its
/// wash states whether that figure is good news (`.accent`/`.success`) or not
/// (`.warning`/`.danger`).
struct HeroCard<Content: View>: View {
    var tone: Theme.Tone
    var content: Content

    init(tone: Theme.Tone = .accent, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            content
        }
        .padding(Theme.Spacing.heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            HeroBackground(wash: tone.color.opacity(0.10), edge: tone.color.opacity(0.22))
        }
    }
}

/// The hero figure with a progress bar: eyebrow, amount, bar, caption and a
/// progress badge. The `accent` colour washes the card and fills the bar.
struct AccentCard: View {
    let eyebrow: LocalizedStringKey
    let amount: Decimal
    let caption: LocalizedStringKey
    /// 0...1 — drives the inline progress bar.
    let progress: Double
    let progressLabel: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(eyebrow)
                    .font(Theme.Typography.eyebrow)
                    .foregroundStyle(Theme.textSecondary)
                MoneyText(amount, size: .hero)
            }

            ProgressBar(value: progress, tint: accent)

            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Text(caption)
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Spacing.sm)
                Pill(text: progressLabel, style: .solid(accent))
            }
        }
        .padding(Theme.Spacing.heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            HeroBackground(wash: accent.opacity(0.10), edge: accent.opacity(0.22))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress

/// Legacy progress bar for use *on a strong fill* (the old solid hero cards).
/// Track and fill both derive from `foreground`, which defaults to
/// `onAccent` — legible on the accent and every semantic colour in both
/// appearances. On a normal surface use `ProgressBar`.
struct ProgressTrack: View {
    let progress: Double
    var foreground: Color = Theme.onAccent
    var fill: Color = Theme.onAccent

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(foreground.opacity(0.22))
                // The 6pt floor keeps a sliver visible at 1%, but at 0% it
                // would leave a stray dot on an otherwise empty track.
                Capsule()
                    .fill(fill)
                    .frame(
                        width: progress <= 0
                            ? 0
                            : max(6, geometry.size.width * progress.clamped())
                    )
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue(Text(verbatim: "\(Int((progress.clamped() * 100).rounded()))%"))
    }
}

/// Progress on a normal surface: a muted track with a tinted fill. Fills from
/// the leading edge, so it runs right-to-left in Arabic with no extra work.
struct ProgressBar: View {
    let value: Double
    var tint: Color
    var track: Color
    var height: CGFloat

    init(value: Double, tint: Color = Theme.accent, track: Color = Theme.surfaceMuted, height: CGFloat = 8) {
        self.value = value
        self.tint = tint
        self.track = track
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: value <= 0 ? 0 : max(height, geometry.size.width * value.clamped()))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text(verbatim: "\(Int((value.clamped() * 100).rounded()))%"))
    }
}

private extension Double {
    func clamped() -> Double { Swift.min(Swift.max(self, 0), 1) }
}

// MARK: - Badges

/// Small status badge. Rounded rectangle, caption type, tabular digits.
///
///     Pill(text: "Paid", style: .tone(.success))
///     Pill(text: "Planned", style: .muted(dot: Theme.info))
struct Pill: View {
    enum Style {
        /// Soft wash of a colour with the colour as text. Pass a semantic
        /// token (`Theme.success`…) — they are text-safe on their own wash.
        case accent(Color)
        /// Neutral fill with a coloured status dot — for quieter state.
        case muted(dot: Color?)
        /// Outlined, for a value that is informative rather than a status.
        case outlined(Color)
        /// Soft wash of a semantic tone. The preferred status badge.
        case tone(Theme.Tone)
        /// Solid fill with a computed legible foreground — for emphasis.
        case solid(Color)
    }

    let text: String
    var style: Style = .muted(dot: nil)
    /// Optional leading SF Symbol, so a status carries more than colour.
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .fontWeight(.semibold)
            } else if case .muted(let dot) = style, let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
            }
            Text(text)
                .font(Theme.Typography.captionStrong)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .foregroundStyle(foreground)
        .background(background, in: .rect(cornerRadius: Theme.Radius.badge, style: .continuous))
        .overlay {
            if case .outlined(let color) = style {
                RoundedRectangle(cornerRadius: Theme.Radius.badge, style: .continuous)
                    .strokeBorder(color.opacity(0.6), lineWidth: Theme.Border.hairline)
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .accent(let color):   color
        case .muted:               Theme.textPrimary
        case .outlined(let color): color
        case .tone(let tone):      tone == .neutral ? Theme.textPrimary : tone.color
        case .solid(let color):    color.readableForeground
        }
    }

    private var background: Color {
        switch style {
        case .accent(let color): color.opacity(0.14)
        case .muted:             Theme.surfaceMuted
        case .outlined:          .clear
        case .tone(let tone):    tone.soft
        case .solid(let color):  color
        }
    }
}

/// A change since a baseline: arrow, signed amount, green if it is the
/// direction the user wants, red if not. Arrows are vertical so they need no
/// mirroring in Arabic.
struct DeltaBadge: View {
    let amount: Decimal
    let isImprovement: Bool

    var body: some View {
        let tone: Theme.Tone = isImprovement ? .success : .danger
        HStack(spacing: 3) {
            Image(systemName: amount >= 0 ? "arrow.up" : "arrow.down")
                .imageScale(.small)
                .fontWeight(.bold)
            Text(CurrencyFormat.display(amount, sign: .always))
                .font(Theme.Typography.amountCaption)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tone.soft, in: .rect(cornerRadius: Theme.Radius.badge, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// An SF Symbol on a tinted rounded square: leading icon of rows, metric
/// cards and empty states.
struct IconBadge: View {
    let systemName: String
    var foreground: Color
    var fill: Color
    var size: CGFloat

    /// Soft badge in any colour token: the colour on a 14% wash of itself.
    init(_ systemName: String, tint: Color = Theme.accent, size: CGFloat = Theme.Icon.rowBadge) {
        self.systemName = systemName
        self.foreground = tint
        self.fill = tint.opacity(0.14)
        self.size = size
    }

    /// Soft badge in a semantic tone.
    init(_ systemName: String, tone: Theme.Tone, size: CGFloat = Theme.Icon.rowBadge) {
        self.systemName = systemName
        self.foreground = tone.color
        self.fill = tone.soft
        self.size = size
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: Theme.Icon.badgeWeight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Headers & rows

/// Section header: a title with an optional trailing action or figure.
///
///     SectionHeader(title: "Due soon")
///     SectionHeader(title: "Payments") { SectionAction("Add") { … } }
struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Spacing.sm)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// The accent text button that sits at the trailing end of a section header
/// or a card: "Add", "See all".
struct SectionAction: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(Theme.Typography.subheadlineStrong)
            .foregroundStyle(Theme.accent)
            .frame(minHeight: Theme.Icon.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }
}

/// A list row: optional leading view, title, optional subtitle, trailing view.
/// Put rows in a `GroupedCard` with `RowDivider()`s between them.
///
///     ListRow(title: Text(debt.name), subtitle: Text("Due on the 12th")) {
///         IconBadge("creditcard.fill", tone: .danger)
///     } trailing: {
///         MoneyText(debt.balance)
///     }
struct ListRow<Leading: View, Trailing: View>: View {
    let title: Text
    var subtitle: Text?
    var leading: Leading
    var trailing: Trailing

    init(
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.rowIconGap) {
            leading

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                title
                    .font(Theme.Typography.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    subtitle
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            trailing
        }
        .padding(.vertical, Theme.Spacing.rowVertical)
        .frame(minHeight: Theme.Icon.minTapTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

extension ListRow where Leading == EmptyView {
    init(title: Text, subtitle: Text? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    init(title: Text, subtitle: Text? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// What a key–value row or a stat tile shows.
enum DisplayValue {
    case text(String)
    case money(Decimal, tone: MoneyText.Tone, sign: MoneySign)
}

/// A label with a value at the trailing end: summaries, breakdowns, settings.
struct KeyValueRow: View {
    let label: LocalizedStringKey
    let value: DisplayValue

    init(_ label: LocalizedStringKey, value: String) {
        self.label = label
        self.value = .text(value)
    }

    init(_ label: LocalizedStringKey, amount: Decimal, tone: MoneyText.Tone = .neutral, sign: MoneySign = .automatic) {
        self.label = label
        self.value = .money(amount, tone: tone, sign: sign)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Theme.Spacing.sm)
            switch value {
            case .text(let string):
                Text(string)
                    .font(Theme.Typography.subheadlineStrong)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.trailing)
            case .money(let amount, let tone, let sign):
                MoneyText(amount, size: .small, tone: tone, sign: sign)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

/// One figure with its label, for a row of two or three facts under a hero.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: DisplayValue

    init(_ label: LocalizedStringKey, value: String) {
        self.label = label
        self.value = .text(value)
    }

    init(_ label: LocalizedStringKey, amount: Decimal, tone: MoneyText.Tone = .neutral) {
        self.label = label
        self.value = .money(amount, tone: tone, sign: .automatic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            switch value {
            case .text(let string):
                Text(string)
                    .font(Theme.Typography.figure)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            case .money(let amount, let tone, let sign):
                MoneyText(amount, size: .medium, tone: tone, sign: sign)
            }
        }
        .surfaceCard(padding: Theme.Spacing.md, radius: Theme.Radius.card)
        .accessibilityElement(children: .combine)
    }
}

/// A row inside a grouped card: title, supporting copy, then a status line.
struct DetailRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let value: String
    let statusText: String
    let statusDot: Color
    let tag: String
    let tagColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(value)
                    .font(Theme.Typography.amount)
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(subtitle)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Pill(text: statusText, style: .muted(dot: statusDot))
                Pill(text: tag, style: .accent(tagColor))
                Spacer(minLength: 0)
            }
            .padding(.top, Theme.Spacing.xxs)
        }
        .padding(.vertical, Theme.Spacing.rowVertical)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

/// Every button that is not a toolbar item or a plain row.
///
///     Button("Record a payment") { … }.buttonStyle(.primaryAction)
///     Button("Cancel") { … }.buttonStyle(.secondaryAction)
///     Button("Delete debt", role: .destructive) { … }.buttonStyle(.destructiveAction)
///
/// Disabled state comes from `.disabled(_:)`; never fade a button by hand.
struct ActionButtonStyle: ButtonStyle {
    enum Kind: Sendable, Hashable {
        /// Solid accent. One per screen at most.
        case primary
        /// Surface with a border. The alternative to the primary.
        case secondary
        /// Soft danger wash. Irreversible actions.
        case destructive
        /// Accent text, no container. Tertiary actions inside cards.
        case quiet
    }

    enum Size: Sendable, Hashable {
        /// 52pt. Bottom-of-screen and sheet actions.
        case large
        /// 44pt. Inside cards.
        case regular
        /// 36pt visual (44pt touch). Inline next to content.
        case compact
    }

    var kind: Kind
    var size: Size
    var fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: Kind = .primary, size: Size = .large, fullWidth: Bool = true) {
        self.kind = kind
        self.size = size
        self.fullWidth = fullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .compact ? Theme.Typography.buttonSmall : Theme.Typography.button)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .quiet ? Theme.Spacing.xs : Theme.Spacing.lg)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil, minHeight: height)
            .background(background, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.strokeStrong, lineWidth: Theme.Border.hairline)
                }
            }
            .frame(minHeight: Theme.Icon.minTapTarget)
            .contentShape(.rect)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }

    private var height: CGFloat {
        switch size {
        case .large:   52
        case .regular: 44
        case .compact: 36
        }
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.textDisabled }
        switch kind {
        case .primary:     return Theme.onAccent
        case .secondary:   return Theme.textPrimary
        case .destructive: return Theme.danger
        case .quiet:       return Theme.accent
        }
    }

    private var background: Color {
        switch kind {
        case .primary:     return isEnabled ? Theme.accent : Theme.surfaceMuted
        case .secondary:   return Theme.surface
        case .destructive: return isEnabled ? Theme.dangerSoft : Theme.surfaceMuted
        case .quiet:       return .clear
        }
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    static var primaryAction: ActionButtonStyle { ActionButtonStyle(kind: .primary) }
    static var secondaryAction: ActionButtonStyle { ActionButtonStyle(kind: .secondary) }
    static var destructiveAction: ActionButtonStyle { ActionButtonStyle(kind: .destructive) }
    static var quietAction: ActionButtonStyle { ActionButtonStyle(kind: .quiet, size: .regular, fullWidth: false) }

    static func action(
        _ kind: ActionButtonStyle.Kind,
        size: ActionButtonStyle.Size = .large,
        fullWidth: Bool = true
    ) -> ActionButtonStyle {
        ActionButtonStyle(kind: kind, size: size, fullWidth: fullWidth)
    }
}

/// Convenience: a titled button in one of the action styles.
///
///     ActionButton("Record a payment", systemImage: "plus") { isPaying = true }
struct ActionButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var kind: ActionButtonStyle.Kind
    var size: ActionButtonStyle.Size
    var fullWidth: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        kind: ActionButtonStyle.Kind = .primary,
        size: ActionButtonStyle.Size = .large,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(ActionButtonStyle(kind: kind, size: size, fullWidth: fullWidth))
    }
}

/// A selectable chip: month pickers, category choices, quick amounts.
/// Selected is solid accent; unselected is the surface with a hairline.
struct FilterChip: View {
    let title: Text
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    init(verbatim title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                title
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(Theme.Typography.subheadlineStrong)
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(
                isSelected ? Theme.accent : Theme.surface,
                in: .rect(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.stroke, lineWidth: Theme.Border.hairline)
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Forms

/// Chrome for a text field: surface fill, hairline border, accent ring when
/// focused, danger ring when invalid.
struct FieldChrome: ViewModifier {
    var isFocused: Bool
    var isInvalid: Bool

    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused || isInvalid ? Theme.Border.focus : Theme.Border.hairline)
            }
            .animation(Theme.Motion.quick, value: isFocused)
    }

    private var borderColor: Color {
        if isInvalid { return Theme.danger }
        return isFocused ? Theme.accent : Theme.strokeStrong
    }
}

extension View {
    func fieldChrome(isFocused: Bool = false, isInvalid: Bool = false) -> some View {
        modifier(FieldChrome(isFocused: isFocused, isInvalid: isInvalid))
    }
}

/// A labelled form field: label above, the control, then help or an error.
/// The control inside applies `.fieldChrome(isFocused:)` itself, because only
/// it owns its focus.
struct FormField<Content: View>: View {
    let label: LocalizedStringKey
    var help: LocalizedStringKey?
    var error: LocalizedStringKey?
    var content: Content

    init(
        _ label: LocalizedStringKey,
        help: LocalizedStringKey? = nil,
        error: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.help = help
        self.error = error
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Typography.footnoteStrong)
                .foregroundStyle(Theme.textSecondary)
            content
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.danger)
            } else if let help {
                Text(help)
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Feedback

/// An inline message inside a screen: a tip, a warning that the plan is not
/// feasible, an error. Icon + title + optional message on the tone's wash.
struct InlineNotice: View {
    let tone: Theme.Tone
    let title: LocalizedStringKey
    var message: LocalizedStringKey?

    init(_ tone: Theme.Tone, title: LocalizedStringKey, message: LocalizedStringKey? = nil) {
        self.tone = tone
        self.title = title
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: tone.symbol)
                .font(Theme.Typography.bodyStrong)
                .foregroundStyle(tone == .neutral ? Theme.textSecondary : tone.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.subheadlineStrong)
                    .foregroundStyle(Theme.textPrimary)
                if let message {
                    Text(message)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.soft, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Empty state for a list or a screen: icon badge, title, message and an
/// optional action.
struct EmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            IconBadge(systemImage, tone: .accent, size: 56)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                ActionButton(actionTitle, kind: .secondary, size: .regular, fullWidth: false, action: action)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .padding(.horizontal, Theme.Spacing.xxl)
    }
}

// MARK: - Tab bar

/// Floating navigation: one raised bar holding the destinations with the
/// accent action inline, between them.
struct FloatingTabBar: View {
    @Binding var selection: Int
    let actionTitle: LocalizedStringKey
    /// When the action has opened something, it turns into a dismiss.
    var isActionActive: Bool = false
    let onAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        selection: Binding<Int>,
        actionTitle: LocalizedStringKey,
        isActionActive: Bool = false,
        onAction: @escaping () -> Void
    ) {
        self._selection = selection
        self.actionTitle = actionTitle
        self.isActionActive = isActionActive
        self.onAction = onAction
    }

    /// A tab's mark. Most are SF Symbols; the board draws its own, because no
    /// symbol is three circles of three different sizes.
    enum TabIcon {
        case system(String)
        case bubbles
    }

    private let tabs: [(icon: TabIcon, label: LocalizedStringKey)] = [
        (.system("house"), "Today"),
        (.bubbles, "Board"),
        (.system("person.2"), "Split"),
        (.system("wallet.pass"), "Wallet")
    ]
    /// Destinations before the action; the rest sit after it. Two either side
    /// keeps the accent button centred.
    private let actionIndex = 2

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<actionIndex, id: \.self) { tabButton(index: $0) }
            actionButton
            ForEach(actionIndex..<tabs.count, id: \.self) { tabButton(index: $0) }
        }
        .padding(6)
        .background(Theme.surfaceRaised, in: .rect(cornerRadius: Theme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: Theme.Border.hairline)
        }
        .elevation(.raised)
    }

    private var actionButton: some View {
        Button(action: onAction) {
            Group {
                if isActionActive {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Label(actionTitle, systemImage: "plus")
                        .font(Theme.Typography.subheadlineStrong)
                }
            }
            .foregroundStyle(isActionActive ? Theme.textPrimary : Theme.onAccent)
            .frame(height: 44)
            .padding(.horizontal, isActionActive ? 14 : 16)
            .background(
                isActionActive ? Theme.surfaceMuted : Theme.accent,
                in: .rect(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, 2)
        .animation(Theme.Motion.adaptive(Theme.Motion.emphasized, reduceMotion: reduceMotion), value: isActionActive)
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
                    Image(systemName: isSelected ? name + ".fill" : name)
                        .font(.system(size: 18, weight: Theme.Icon.weight))
                        .symbolEffect(.bounce, value: isSelected)
                case .bubbles:
                    BubblesMark()
                        .frame(width: 20, height: 20)
                }
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            .frame(width: 50, height: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.accentSoft)
                }
            }
            .animation(Theme.Motion.adaptive(Theme.Motion.standard, reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tabs[index].label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
