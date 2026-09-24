import SwiftUI
import UIKit

/// Veralify's visual language: **"Quiet Ledger"**.
///
/// Warm paper in the light, deep green-black ink in the dark, one evergreen
/// accent, and figures set in a serif like a well-kept bank statement. The
/// product is a household paying down debt, so the tone is calm and certain
/// rather than loud: colour is kept for meaning, surfaces are separated by
/// hairlines rather than shadows, and the money is the loudest thing on screen.
///
/// Every colour here is adaptive — it has a light and a dark value and follows
/// the system appearance. Three rules keep it honest:
///
/// 1. **Colour is semantic, never decorative.** Success means money in or a
///    debt going down; danger means money out, a shortfall or something late.
///    A shortfall is never shown on a cheerful surface.
/// 2. **Every "strong" colour pairs with `onAccent`.** Accent, success,
///    warning, danger and info are deep tones in light mode (white text on
///    them) and light tones in dark mode (ink text on them), so
///    `Theme.onAccent` is legible on any of them in either appearance.
/// 3. **Status never rides on colour alone.** A tone carries an icon or a
///    word as well — see `Theme.Tone.symbol`.
///
/// `DESIGN_SYSTEM.md` at the repo's iOS root is the usage guide for all of it.
enum Theme {

    // MARK: - Surfaces

    /// The screen itself. Warm paper / deep ink.
    static let canvas = Color(light: 0xF5F3EE, dark: 0x0F1312)
    /// Cards and grouped lists sitting on the canvas.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1F1D)
    /// Fills *inside* a card: fields, unselected chips, progress tracks, stat
    /// tiles nested in a card.
    static let surfaceMuted = Color(light: 0xEEEBE4, dark: 0x252B28)
    /// Things that float above content: the tab bar, toasts, menus.
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x232927)

    /// Hairline between rows and around cards.
    static let stroke = Color(light: 0xE4E0D7, dark: 0x2B322F)
    /// Field borders, focus-less outlines and chart baselines.
    static let strokeStrong = Color(light: 0xB9B2A5, dark: 0x4A534E)
    /// Colour of an elevation shadow. Barely there on paper, deeper on ink.
    static let shadow = Color(light: 0x1B2420, dark: 0x000000, lightOpacity: 0.08, darkOpacity: 0.5)

    // MARK: - Text

    /// Headings, figures, row titles. ≥ 12:1 on every surface.
    static let textPrimary = Color(light: 0x17201C, dark: 0xECF0EE)
    /// Supporting copy, labels. ≥ 6:1 on every surface.
    static let textSecondary = Color(light: 0x4F5A54, dark: 0xAEB7B2)
    /// Captions, timestamps, placeholders. ≥ 4.5:1 on every surface (AA).
    static let textTertiary = Color(light: 0x5F6963, dark: 0x8C9690)
    /// Disabled controls only — exempt from contrast rules, never for content.
    static let textDisabled = Color(light: 0xA3A9A4, dark: 0x5A625E)

    // MARK: - Brand

    /// Evergreen. The one brand colour: primary actions, selection, links,
    /// the tint. 6.4:1 on white; 8.3:1 on the dark surface.
    static let accent = Color(light: 0x0D6B63, dark: 0x5CC8BC)
    /// Tinted wash for selected rows, the hero card and icon badges.
    static let accentSoft = Color(light: 0xE0EFEC, dark: 0x15332F)
    /// Text and glyphs on any strong fill: accent, success, warning, danger,
    /// info. White in light mode, deep ink in dark mode.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x08201D)

    // MARK: - Semantic

    /// Money in, a debt going down, done. Text-safe on every surface.
    static let success = Color(light: 0x1D7342, dark: 0x62C98D)
    static let successSoft = Color(light: 0xE2F1E6, dark: 0x17301F)
    /// Due soon, needs attention. Text-safe (an ochre, not a yellow).
    static let warning = Color(light: 0x8F5500, dark: 0xEDB65A)
    static let warningSoft = Color(light: 0xFAEEDB, dark: 0x372A14)
    /// Money out, overdue, a shortfall, destructive actions.
    static let danger = Color(light: 0xB3261E, dark: 0xFF8A7E)
    static let dangerSoft = Color(light: 0xFBE6E3, dark: 0x3B1D1A)
    /// Neutral information, planned (not yet paid) items.
    static let info = Color(light: 0x2456B0, dark: 0x86AEF7)
    static let infoSoft = Color(light: 0xE3EAF8, dark: 0x1A2640)

    // MARK: - Money semantics

    /// Money arriving. Alias of `success`, named for what it means on a row.
    static let moneyIn = success
    /// Money leaving. Alias of `danger`.
    static let moneyOut = danger

    /// The colour a signed figure takes when its sign is the news (a flow, a
    /// change). Balances and totals stay `textPrimary` — see `MoneyText.Tone`.
    static func moneyColor(_ amount: Decimal) -> Color {
        if amount > 0 { return success }
        if amount < 0 { return danger }
        return textPrimary
    }

    // MARK: - Categorical

    /// Distinct hues for categories and debts, in fixed order.
    ///
    /// A category keeps its colour however the ranking moves — colour follows
    /// the thing, never its rank. Validated with the data-viz palette checker
    /// against both card surfaces: worst adjacent colour-blind ΔE 9.1 (light) /
    /// 8.4 (dark), normal-vision ΔE ≥ 19. Three light-mode slots sit under 3:1
    /// on white, so a chart always labels its slices (legend or list).
    /// Never use these for text; text stays in the text tokens.
    static let categorical: [Color] = [
        Color(light: 0x2A78D6, dark: 0x3987E5),  // blue
        Color(light: 0xEB6834, dark: 0xD95926),  // orange
        Color(light: 0x1BAF7A, dark: 0x199E70),  // aqua
        Color(light: 0xEDA100, dark: 0xC98500),  // yellow
        Color(light: 0xE87BA4, dark: 0xD55181),  // magenta
        Color(light: 0x008300, dark: 0x008300),  // green
        Color(light: 0x4A3AA7, dark: 0x9085E9)   // violet
    ]

    /// Past the last colour, one grey. Never a generated hue — two generated
    /// hues are a pair nobody can tell apart.
    static let categoricalOther = Color(light: 0x7A807C, dark: 0x7D8581)

    static func categorical(_ index: Int) -> Color {
        index >= 0 && index < categorical.count ? categorical[index] : categoricalOther
    }

    // MARK: - Tone

    /// A semantic role, for components that take "what kind of thing is this"
    /// rather than a raw colour: badges, notices, hero cards, icon badges.
    enum Tone: Sendable, Hashable {
        case neutral, accent, success, warning, danger, info

        /// The strong colour: text-safe on surfaces, pairs with `onAccent`.
        var color: Color {
            switch self {
            case .neutral: Theme.textSecondary
            case .accent:  Theme.accent
            case .success: Theme.success
            case .warning: Theme.warning
            case .danger:  Theme.danger
            case .info:    Theme.info
            }
        }

        /// The tinted wash behind a badge, notice or hero.
        var soft: Color {
            switch self {
            case .neutral: Theme.surfaceMuted
            case .accent:  Theme.accentSoft
            case .success: Theme.successSoft
            case .warning: Theme.warningSoft
            case .danger:  Theme.dangerSoft
            case .info:    Theme.infoSoft
            }
        }

        /// The SF Symbol that carries the same meaning, so colour is never the
        /// only signal.
        var symbol: String {
            switch self {
            case .neutral: "circle.fill"
            case .accent:  "sparkle"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger:  "exclamationmark.octagon.fill"
            case .info:    "info.circle.fill"
            }
        }
    }

    /// Tone for a signed figure: positive success, negative danger, zero neutral.
    static func tone(for amount: Decimal) -> Tone {
        if amount > 0 { return .success }
        if amount < 0 { return .danger }
        return .neutral
    }

    // MARK: - Spacing

    /// The only paddings and gaps a screen uses. A 4pt grid.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48

        /// Horizontal margin of every screen's content.
        static let gutter: CGFloat = 20
        /// Between two sections of a screen (header + its content = a section).
        static let section: CGFloat = 28
        /// Between cards inside one section, and between a header and its card.
        static let stack: CGFloat = 12
        /// Inside a card.
        static let cardPadding: CGFloat = 16
        /// Inside the hero card.
        static let heroPadding: CGFloat = 20
        /// Vertical padding of a list row inside a grouped card.
        static let rowVertical: CGFloat = 12
        /// Space between a row's leading icon and its text.
        static let rowIconGap: CGFloat = 12
        /// Bottom inset on a tab root so the last row clears the floating bar.
        static let tabBarClearance: CGFloat = 112
    }

    // MARK: - Radii

    /// Continuous ("squircle") corners throughout. Capsules are reserved for
    /// the tab bar's selection and tiny indicators; everything else is a
    /// rounded rectangle.
    enum Radius {
        /// Legacy: capsule. Prefer `control` for new work.
        static let pill: CGFloat = 999
        /// Cards and grouped lists.
        static let card: CGFloat = 16
        /// Tiles, fields and badges-with-icons *inside* a card.
        static let inner: CGFloat = 10
        /// Buttons, chips, segmented choices.
        static let control: CGFloat = 12
        /// Status badges (`Pill`).
        static let badge: CGFloat = 6
        /// The hero card and the floating tab bar.
        static let hero: CGFloat = 22
        /// Sheets (`presentationCornerRadius`).
        static let sheet: CGFloat = 28
    }

    // MARK: - Borders & elevation

    enum Border {
        /// Cards, dividers.
        static let hairline: CGFloat = 1
        /// Outlined badges, selected-but-quiet chips.
        static let emphasis: CGFloat = 1.5
        /// Focused field.
        static let focus: CGFloat = 2
    }

    /// Two levels only. Content is flat (a hairline, no shadow); only things
    /// that float over content cast a shadow.
    enum Elevation: Sendable {
        case flat
        case raised

        var radius: CGFloat { self == .flat ? 0 : 18 }
        var y: CGFloat { self == .flat ? 0 : 6 }
    }

    // MARK: - Typography

    /// Named text styles. Every one is built on a Dynamic Type text style, so
    /// it scales with the user's setting. Words are set in the system face
    /// (SF Pro / SF Arabic); **figures** are set in the system serif (New York)
    /// with tabular digits — money reads like a statement, and columns align.
    ///
    /// No letter-spacing and no forced uppercase anywhere: both break Arabic.
    enum Typography {
        /// Screen titles that sit in content (onboarding, empty screens).
        static var largeTitle: Font { .system(.largeTitle, weight: .bold) }
        /// Card and sheet titles.
        static var title: Font { .system(.title2, weight: .bold) }
        static var title3: Font { .system(.title3, weight: .semibold) }
        /// Section headers, row titles that lead.
        static var headline: Font { .system(.headline, weight: .semibold) }
        static var body: Font { .body }
        static var bodyStrong: Font { .system(.body, weight: .semibold) }
        static var callout: Font { .callout }
        /// Supporting copy under a title, list-row subtitles.
        static var subheadline: Font { .subheadline }
        static var subheadlineStrong: Font { .system(.subheadline, weight: .semibold) }
        static var footnote: Font { .footnote }
        static var footnoteStrong: Font { .system(.footnote, weight: .semibold) }
        /// Timestamps, helper text.
        static var caption: Font { .caption }
        static var captionStrong: Font { .system(.caption, weight: .semibold) }
        /// The small label above a figure ("Left this month"). Sentence case.
        static var eyebrow: Font { .system(.footnote, weight: .medium) }
        /// Button labels.
        static var button: Font { .system(.body, weight: .semibold) }
        static var buttonSmall: Font { .system(.subheadline, weight: .semibold) }

        // Figures — always tabular.

        /// The one number a screen is about. `MoneyText(.hero)` goes larger
        /// still via `@ScaledMetric`; use this for non-money hero numbers.
        static var figureHero: Font { .system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit() }
        /// Secondary headline figures: stat tiles, metric cards.
        static var figureLarge: Font { .system(.title2, design: .serif, weight: .semibold).monospacedDigit() }
        static var figure: Font { .system(.title3, design: .serif, weight: .semibold).monospacedDigit() }
        /// Amounts in list rows. Sans, so a column of them stays compact.
        static var amount: Font { .system(.body, weight: .semibold).monospacedDigit() }
        static var amountSmall: Font { .system(.subheadline, weight: .semibold).monospacedDigit() }
        static var amountCaption: Font { .system(.caption, weight: .semibold).monospacedDigit() }
    }

    // MARK: - Iconography

    /// SF Symbols only. Medium weight beside body text, semibold inside
    /// badges; hierarchical rendering for multi-part symbols.
    enum Icon {
        static var weight: Font.Weight { .medium }
        static var badgeWeight: Font.Weight { .semibold }
        /// Point sizes for glyphs that are not tied to a text style.
        static let small: CGFloat = 13
        static let medium: CGFloat = 17
        static let large: CGFloat = 22
        /// Leading icon badge in a list row.
        static let rowBadge: CGFloat = 36
        /// Minimum tappable area (HIG).
        static let minTapTarget: CGFloat = 44
    }

    // MARK: - Motion

    /// Calm, short, and never in the way. Every animation a screen writes goes
    /// through `Motion.adaptive(_:reduceMotion:)` or `.themeAnimation(_:value:)`
    /// so Reduce Motion swaps movement for a short cross-fade.
    enum Motion {
        /// Hover-like feedback, toggles, chips: 150 ms.
        static var quick: Animation { .easeOut(duration: 0.15) }
        /// Most state changes: 300 ms, no overshoot.
        static var standard: Animation { .smooth(duration: 0.3) }
        /// Something arriving or completing (a payment recorded): gentle spring.
        static var emphasized: Animation { .spring(duration: 0.45, bounce: 0.15) }
        /// Button press response.
        static var press: Animation { .spring(duration: 0.25, bounce: 0.2) }
        /// Card entrance on first appearance.
        static var entrance: Animation { .smooth(duration: 0.45) }
        /// Numbers counting to a new value.
        static var count: Animation { .smooth(duration: 0.8) }
        /// The Reduce Motion replacement for all of the above.
        static var reduced: Animation { .easeInOut(duration: 0.2) }

        /// Delay between consecutive cards in a staggered entrance.
        static let staggerStep: Double = 0.05
        /// Distance a card rises during its entrance.
        static let entranceRise: CGFloat = 10

        static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : animation
        }
    }
}

// MARK: - Legacy tokens

/// The previous identity's names, remapped onto the new palette so unmigrated
/// screens keep compiling and pick up the new look. Each is deprecated with
/// the token to use instead — a warning, not an error.
extension Theme {
    @available(*, deprecated, message: "Use Theme.canvas")
    static let background = canvas
    @available(*, deprecated, message: "Use Theme.surfaceMuted (fills inside a card) or Theme.surfaceRaised (floating)")
    static let surfaceElevated = surfaceMuted
    @available(*, deprecated, message: "Use Theme.accent")
    static let lime = accent
    @available(*, deprecated, message: "Use Theme.info")
    static let blue = info
    @available(*, deprecated, message: "Use Theme.warning")
    static let yellow = warning
    @available(*, deprecated, message: "Use Theme.danger (or Theme.moneyOut for money leaving)")
    static let red = danger
    @available(*, deprecated, message: "Use Theme.success (or Theme.moneyIn for money arriving)")
    static let green = success
    @available(*, deprecated, message: "Use Theme.dangerSoft")
    static let redSurface = dangerSoft
}

// MARK: - Colour helpers

/// Ink used for text on light fills whatever the appearance, so a computed
/// foreground never flips to white on a light colour in dark mode.
private let inkHex: UInt32 = 0x0B1512

extension UIColor {
    /// A static sRGB colour from `0xRRGGBB`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// WCAG relative luminance of the colour as it currently resolves.
    var relativeLuminance: CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio between two resolved colours.
    static func contrastRatio(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let a = first.relativeLuminance
        let b = second.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Whether dark ink beats white for text on this (resolved) colour.
    var prefersInkForeground: Bool {
        UIColor.contrastRatio(UIColor(hex: inkHex), self) >= UIColor.contrastRatio(.white, self)
    }
}

/// Lets a `UIColor` travel into a dynamic provider under strict concurrency.
/// Colours are immutable, so sharing one across threads is safe.
private struct ColorBox: @unchecked Sendable {
    let color: UIColor
}

extension Color {
    /// An adaptive colour: `light` in the light appearance, `dark` in the dark
    /// one (including increased-contrast variants of each).
    init(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: CGFloat(darkOpacity))
                : UIColor(hex: light, alpha: CGFloat(lightOpacity))
        })
    }

    /// Whether near-black text is legible on this colour, as it resolves in the
    /// current trait environment. Prefer `readableForeground`, which stays
    /// correct when the appearance changes.
    @MainActor
    var prefersDarkForeground: Bool {
        UIColor(self).resolvedColor(with: UITraitCollection.current).prefersInkForeground
    }

    /// Legible foreground for text sitting on this colour: dark ink or white,
    /// whichever has more contrast. Adaptive — it re-evaluates when an
    /// adaptive fill changes between light and dark.
    var readableForeground: Color {
        let box = ColorBox(color: UIColor(self))
        return Color(uiColor: UIColor { traits in
            box.color.resolvedColor(with: traits).prefersInkForeground
                ? UIColor(hex: inkHex)
                : .white
        })
    }

    /// A static (non-adaptive) sRGB colour from `0xRRGGBB`. Design/ only —
    /// screens use tokens.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
