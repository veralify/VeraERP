# Veralify design system — "Quiet Ledger"

The rules every screen follows. Source of truth in code: `Veralify/Design/`
(`Theme.swift` tokens, `Components.swift` components, `Entrance.swift` /
`PressStyle.swift` motion, `DateField.swift`, `CategoryStyle.swift`).
If this document and the code disagree, the code wins and this doc is the bug.

## 1. Direction

Warm paper in the light, deep green-black ink in the dark, one evergreen accent,
and money set in a serif like a well-kept bank statement. The app helps a
household pay down debt, so it is **calm, certain and encouraging**: colour is
kept for meaning, surfaces are separated by hairlines rather than shadows, and
the figure a screen is about is always the loudest thing on it.

It replaces the old identity completely: no dark-only lock, no near-black
surfaces, no neon lime, no capsule "pills", no 20pt cards.

## 2. Appearance

- The app follows the system appearance (light **and** dark). There is no
  `.preferredColorScheme` anywhere.
- Every colour token is adaptive (`Color(light:dark:)`). Using only tokens gives
  you dark mode for free. **Check every screen in both appearances.**
- Never hard-code `.white`, `.black`, `Color(red:…)` or hex in Features. If you
  need a colour that does not exist, it is a design-system change — ask; do not
  inline it.

## 3. Tokens

All tokens live on `Theme`. Hex values are light / dark.

### 3.1 Surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `Theme.canvas` | `#F5F3EE` | `#0F1312` | Screen background, sheet background, nav bar. |
| `Theme.surface` | `#FFFFFF` | `#1A1F1D` | Cards and grouped lists on the canvas; secondary buttons; fields. |
| `Theme.surfaceMuted` | `#EEEBE4` | `#252B28` | Fills *inside* a card: unselected segments, progress tracks, value wells, disabled buttons. |
| `Theme.surfaceRaised` | `#FFFFFF` | `#232927` | Things floating over content: tab bar, toasts, menus. Always with `.elevation(.raised)`. |
| `Theme.stroke` | `#E4E0D7` | `#2B322F` | Hairlines: card borders, `RowDivider`, unselected chip borders. |
| `Theme.strokeStrong` | `#B9B2A5` | `#4A534E` | Field borders, secondary-button border, chart baselines. |
| `Theme.shadow` | `#1B2420` @8% | `#000` @50% | Only via `.elevation(.raised)`. |

### 3.2 Text

| Token | Light | Dark | Use | Contrast (worst surface) |
|---|---|---|---|---|
| `Theme.textPrimary` | `#17201C` | `#ECF0EE` | Headings, figures, row titles, values. | ≥ 12:1 |
| `Theme.textSecondary` | `#4F5A54` | `#AEB7B2` | Supporting copy, labels, eyebrows. | ≥ 6:1 |
| `Theme.textTertiary` | `#5F6963` | `#8C9690` | Captions, timestamps, row subtitles, placeholders. | ≥ 4.5:1 (AA) |
| `Theme.textDisabled` | `#A3A9A4` | `#5A625E` | Disabled controls only. Never for content. | exempt |
| `Theme.onAccent` | `#FFFFFF` | `#08201D` | Text/glyphs on **any** strong fill: `accent`, `success`, `warning`, `danger`, `info`. | ≥ 5.8:1 on all five |

### 3.3 Brand & semantic

| Token | Light | Dark | Meaning |
|---|---|---|---|
| `Theme.accent` | `#0D6B63` | `#5CC8BC` | Evergreen. The only brand colour: primary buttons, selection, links, `.tint`, progress. |
| `Theme.accentSoft` | `#E0EFEC` | `#15332F` | Selected-tab wash, accent badges, hero wash. |
| `Theme.success` / `successSoft` | `#1D7342` / `#E2F1E6` | `#62C98D` / `#17301F` | Money in, a debt going down, paid, done. |
| `Theme.warning` / `warningSoft` | `#8F5500` / `#FAEEDB` | `#EDB65A` / `#372A14` | Due soon, needs attention, "tight". An ochre, text-safe. |
| `Theme.danger` / `dangerSoft` | `#B3261E` / `#FBE6E3` | `#FF8A7E` / `#3B1D1A` | Money out, overdue, shortfall, destructive. |
| `Theme.info` / `infoSoft` | `#2456B0` / `#E3EAF8` | `#86AEF7` / `#1A2640` | Planned / scheduled, neutral information. |
| `Theme.moneyIn` / `moneyOut` | = success / danger | | Name them this way on ledger rows. |

Every strong colour is ≥ 4.9:1 against every surface **and** against its own
soft wash, so it is safe as text. `Theme.Tone` (`.neutral .accent .success
.warning .danger .info`) bundles `color`, `soft` and an SF Symbol (`symbol`) for
components that take a meaning rather than a colour. `Theme.tone(for: amount)`
and `Theme.moneyColor(amount)` map a signed figure to its tone/colour.

### 3.4 Categorical (charts, categories, debts)

Seven hues in fixed order, then one grey. `Theme.categorical(index)` /
`CategoryStyle.colour(category)`.

| # | Light | Dark |
|---|---|---|
| 1 blue | `#2A78D6` | `#3987E5` |
| 2 orange | `#EB6834` | `#D95926` |
| 3 aqua | `#1BAF7A` | `#199E70` |
| 4 yellow | `#EDA100` | `#C98500` |
| 5 magenta | `#E87BA4` | `#D55181` |
| 6 green | `#008300` | `#008300` |
| 7 violet | `#4A3AA7` | `#9085E9` |
| other | `#7A807C` | `#7D8581` |

Validated for colour-blind separation (worst adjacent ΔE 9.1 light / 8.4 dark).
Rules: colour follows the *thing*, never its rank; never cycle past 7 (fold into
"Other"); **never use categorical colours for text**; charts always label
slices (legend or list), because three light-mode hues are below 3:1 on white.
Category glyphs use `CategoryStyle.badge(_:)`, which already mixes the hue
toward the text colour so the glyph stays legible.

### 3.5 Spacing — `Theme.Spacing`

4pt grid: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48`.

Semantic spacing (prefer these):

| Token | Value | Use |
|---|---|---|
| `gutter` | 20 | Horizontal padding of every screen's scroll content. |
| `section` | 28 | Vertical gap between sections (the root `VStack(spacing:)`). |
| `stack` | 12 | Between a section header and its content; between cards in a section. |
| `cardPadding` | 16 | Inside a card. |
| `heroPadding` | 20 | Inside the hero card. |
| `rowVertical` | 12 | Vertical padding of a row in a grouped card. |
| `rowIconGap` | 12 | Leading icon → text. |
| `tabBarClearance` | 112 | Bottom padding of a tab root, so content clears the floating bar. |

### 3.6 Radii — `Theme.Radius` (always `style: .continuous`)

| Token | Value | Use |
|---|---|---|
| `badge` | 6 | `Pill`, `DeltaBadge`. |
| `inner` | 10 | Tiles/wells/notices inside a card. |
| `control` | 12 | Buttons, chips, fields. |
| `card` | 16 | Cards, grouped lists, stat tiles. |
| `hero` | 22 | Hero card, floating tab bar. |
| `sheet` | 28 | `presentationCornerRadius`. |
| `pill` | 999 | Legacy only. Capsules are for progress bars and dots — nothing else. |

Write `.rect(cornerRadius: Theme.Radius.card, style: .continuous)` or just use
the components, which already do.

### 3.7 Borders & elevation

- `Theme.Border.hairline` (1) for card edges and dividers; `.emphasis` (1.5);
  `.focus` (2) for a focused/invalid field.
- Two elevation levels: `.elevation(.flat)` (content — a hairline, no shadow)
  and `.elevation(.raised)` (tab bar, toasts). **Cards never cast shadows.**

### 3.8 Typography — `Theme.Typography`

Every style is a Dynamic Type text style, so it scales. Words are in the system
face (SF Pro; SF Arabic for Arabic). **Figures are set in the system serif (New
York) with tabular digits.** Money is always rendered with Latin digits (the
app formats EUR with en_US), so the serif applies in every language.

| Style | Built on | Use |
|---|---|---|
| `largeTitle` | largeTitle bold | In-content screen titles (onboarding, empty screens). |
| `title` | title2 bold | Sheet and card titles. |
| `title3` | title3 semibold | Sub-titles inside a sheet. |
| `headline` | headline semibold | Section headers, leading row titles. |
| `body` / `bodyStrong` | body / semibold | Paragraphs / emphasised body, row titles. |
| `callout` | callout | Longer helper copy. |
| `subheadline` / `subheadlineStrong` | subheadline | Supporting copy, labels / values in key-value rows. |
| `footnote` / `footnoteStrong` | footnote | Row subtitles, captions under cards / field labels. |
| `caption` / `captionStrong` | caption | Timestamps / badge text. |
| `eyebrow` | footnote medium | The label above a hero figure. Sentence case. |
| `button` / `buttonSmall` | body / subheadline semibold | Button labels (set by `ActionButtonStyle`). |
| `figureHero` | largeTitle **serif** semibold, tabular | Non-money hero numbers (e.g. "16 months"). |
| `figureLarge` | title2 serif, tabular | Stat numbers. |
| `figure` | title3 serif, tabular | Payment-card amounts, stat tiles. |
| `amount` | body semibold, tabular | List-row amounts (sans, compact). |
| `amountSmall` / `amountCaption` | subheadline / caption, tabular | Amounts in key-value rows / badges. |

Never: `.font(.system(size:))` for text, `.kerning`/`.tracking` (breaks Arabic
joining), `.textCase(.uppercase)` (meaningless in Arabic, shouty in Latin).

### 3.9 Iconography — `Theme.Icon`

- SF Symbols only. Weight `Theme.Icon.weight` (medium) next to text,
  `badgeWeight` (semibold) inside badges. Let symbols scale with their text
  (`.imageScale`, or the surrounding `.font`) rather than fixed point sizes.
- Outline symbols for unselected / resting, `.fill` for selected or status.
- Directional symbols: prefer vertical arrows (`arrow.up`/`arrow.down`) for
  "more/less". For "go forward" use `chevron.forward` / `arrow.forward`
  (auto-mirror in RTL) — never `chevron.right` / `arrow.right`.
- Icon-only buttons: 44×44 tap target (`Theme.Icon.minTapTarget`) and an
  `.accessibilityLabel`.

### 3.10 Motion — `Theme.Motion`

| Token | Curve | Use |
|---|---|---|
| `quick` | easeOut 150ms | Toggles, chip selection, focus rings. |
| `standard` | smooth 300ms | Most state changes. |
| `emphasized` | spring 450ms, bounce 0.15 | Something arriving/completing. |
| `press` | spring 250ms | Button press (built into styles). |
| `entrance` | smooth 450ms | First appearance of cards (`staggeredAppearance`). |
| `count` | smooth 800ms | Counting numbers. |
| `reduced` | easeInOut 200ms | What everything becomes under Reduce Motion. |

Rules: use `.themeAnimation(Theme.Motion.x, value:)` instead of `.animation`;
inside actions use `withAnimation(Theme.Motion.adaptive(.x, reduceMotion:))`
with `@Environment(\.accessibilityReduceMotion)`. Under Reduce Motion nothing
moves, scales or bounces — it cross-fades. No looping/ambient animation. Money
changes use `.contentTransition(.numericText(...))` (built into `MoneyText`).

## 4. Components (Design/Components.swift unless noted)

### Money
```swift
MoneyText(summary.leftThisMonth, size: .hero)                 // hero figure, serif, scales with Dynamic Type
MoneyText(debt.balance, size: .medium)                        // payment card / tile
MoneyText(record.signedAmount, tone: .signed, sign: .always)  // ledger row: +€40.00 green / −€12.50 red
MoneyText(total, size: .small, tone: .secondary)              // subtotal beside a header
CurrencyFormat.display(amount, sign: .always)                 // String, when you must build text yourself
```
Sizes: `.hero .large .medium .body .small .caption`. Tones: `.neutral
.secondary .signed .positive .negative .onAccent`. Signs: `.automatic` (only
"−"), `.always` ("+"/"−"), `.never`.

### Containers
```swift
Card { … }                               // padded surface card (VStack, spacing md)
someView.surfaceCard()                   // same, as a modifier; surfaceCard(padding: nil) for self-padded content
GroupedCard { row; RowDivider(); row }   // list in one card
RowDivider(inset: Theme.Icon.rowBadge + Theme.Spacing.rowIconGap) // divider aligned to row text
HeroCard(tone: .accent) { … }            // the ONE hero per screen; tone = is this good news?
AccentCard(eyebrow:amount:caption:progress:progressLabel:accent:) // hero figure + progress (legacy API, new look)
```
Screen chrome:
```swift
ScrollView { VStack(spacing: Theme.Spacing.section) { … }
    .padding(.horizontal, Theme.Spacing.gutter) }
.screenBackground()          // canvas under safe areas
.themedNavigationBar()       // nav bar on canvas
.sheet(…) { X().sheetChrome() } // canvas bg, 28pt radius, drag indicator
```

### Headers, rows, values
```swift
SectionHeader(title: "Due soon")
SectionHeader(title: "Payments") { SectionAction("Add", systemImage: "plus") { isPaying = true } }
ListRow(title: Text(record.category), subtitle: Text(record.name)) {
    CategoryStyle.badge(record.category)
} trailing: {
    MoneyText(record.signedAmount, tone: .signed, sign: .always)
}
ListRow(title: Text("Currency")) { Text("EUR") }            // no leading
KeyValueRow("Interest", value: "12.9%")
KeyValueRow("Paid so far", amount: paid, tone: .positive)
StatTile("Remaining", amount: debt.balance)
StatTile("Left", value: String(localized: "\(n) payments"))
```

### Badges & icons
```swift
Pill(text: "Paid", style: .tone(.success), systemImage: "checkmark")
Pill(text: "Planned", style: .muted(dot: Theme.info))
Pill(text: "Cheapest", style: .outlined(Theme.accent))
Pill(text: "62% paid", style: .solid(Theme.accent))
DeltaBadge(amount: delta.amount, isImprovement: delta.isImprovement)
IconBadge("creditcard.fill", tone: .danger)      // 36pt soft square
IconBadge("arrow.down", tint: Theme.success, size: 28)
CategoryStyle.badge(category)                    // Design/CategoryStyle.swift
```
`Pill.Style.accent(color)` is now a soft wash (not a solid block). Prefer `.tone`.

### Buttons
```swift
Button("Record a payment") { … }.buttonStyle(.primaryAction)     // max one per screen
Button("Try with sample data") { … }.buttonStyle(.secondaryAction)
Button("Delete debt", role: .destructive) { … }.buttonStyle(.destructiveAction)
Button("See all") { … }.buttonStyle(.quietAction)
Button { … } label: { … }.buttonStyle(.action(.primary, size: .regular, fullWidth: false))
ActionButton("Record a payment", systemImage: "plus") { isPaying = true }
```
Disabled = `.disabled(true)`; never fade by hand. Sizes: `.large` 52,
`.regular` 44, `.compact` 36 (44 touch). Custom tappables (cards, chips) use
`.buttonStyle(.pressable)` / `.pressableRow` (Design/PressStyle.swift).

### Choice & forms
```swift
FilterChip("This month", isSelected: tf == .month) { tf = .month }
FilterChip(verbatim: "12", isSelected: months == 12) { months = 12 }
FormField("Monthly payment", help: "What you pay on the due day") {
    TextField("0.00", text: $amount).keyboardType(.decimalPad)
        .focused($focused).fieldChrome(isFocused: focused)
}
DateField(label: "Date", date: $date)            // Design/DateField.swift, .row or .chip
```
Native `Toggle`, `Stepper`, `Picker(.segmented)`, `Menu` are fine — they pick
up the tint. Put them on `Theme.surface`.

### Feedback
```swift
InlineNotice(.warning, title: "This plan is tight", message: "…")
EmptyState(systemImage: "list.bullet.rectangle", title: "Nothing this month",
           message: "…", actionTitle: "Add an entry") { … }
ProgressBar(value: progress.fraction)                         // on a surface
ProgressBar(value: f, tint: Theme.warning)
```
`ProgressTrack` is legacy: only for a bar drawn on a *strong fill*.

### Motion helpers (Design/Entrance.swift)
`.staggeredAppearance(i)` (first few cards of a tab root only, i = 0…4),
`.themeAnimation(_:value:)`, `RollingNumber`, `.countUpOnAppear(_:)`.

### Navigation
`FloatingTabBar` (app shell only). Pushed screens use the system nav bar with
`.themedNavigationBar()`; toolbar buttons are plain text in `Theme.accent`.

## 5. Layout rules

- Screen: `ScrollView` → `VStack(spacing: Theme.Spacing.section)` →
  `.padding(.horizontal, Theme.Spacing.gutter)`, `.padding(.top, Theme.Spacing.sm)`,
  bottom `Theme.Spacing.tabBarClearance` on tab roots, `Theme.Spacing.xxxl` on
  pushed screens. `.scrollIndicators(.hidden)`.
- A section is `VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
  SectionHeader; content }`.
- **One hero per screen**, first. Then 2–3 `StatTile`s in an `HStack(spacing:
  Theme.Spacing.stack)` with `.fixedSize(horizontal: false, vertical: true)`.
  Then sections.
- Lists of like things go in **one `GroupedCard` with `RowDivider`s**, not a
  stack of separate cards. Separate cards are for unlike things.
- Horizontal carousels (due soon, quick pay) run edge to edge:
  `.scrollClipDisabled()` and `.contentMargins(.horizontal, Theme.Spacing.gutter)`.
- Rows ≥ 44pt tall; the whole row is the tap target (`.contentShape(.rect)`).
- Group related text for VoiceOver: `.accessibilityElement(children: .combine)`
  on rows and tiles (built into the components).

## 6. Money display rules

1. Always through `MoneyText` or `CurrencyFormat.display` — never
   `Text(CurrencyFormat.string(x))` in new code, never `"-"` hyphen.
2. **Balances, totals, debts owed are neutral** (`textPrimary`). A debt is not
   "red" just for existing; red means *money leaving* or *something wrong*.
3. **Flows and changes are signed and coloured**: ledger rows, day totals,
   deltas → `tone: .signed, sign: .always` (or `.positive` / `.negative` when
   the direction is fixed). `+` green in, `−` red out.
4. Colour is never the only signal: the sign, an arrow, or a word is always there.
5. Hero figure: `MoneyText(x, size: .hero)`, eyebrow above it in
   `Typography.eyebrow`/`textSecondary`, one line of context below.
6. Amounts align to the trailing edge in rows; tabular digits (built in).
7. A figure is one line: `lineLimit(1)` + `minimumScaleFactor` (built in).
   Never truncate a number with "…".

## 7. RTL (Arabic first)

- `leading`/`trailing` only — never `left`/`right` (padding, alignment,
  `.frame(alignment:)`, `HStack` order assumptions, `.offset(x:)` for layout).
- Text alignment: `.multilineTextAlignment(.leading)` (the default), never `.left`.
- Money keeps LTR shape inside Arabic via `CurrencyFormat.display` (Unicode
  isolates) — don't build `"\(sign)\(CurrencyFormat.string(x))"` by hand.
- Directional icons: `chevron.forward`, `arrow.forward`, `arrow.backward`
  (mirror automatically). Progress fills from the leading edge (built in).
- No `.kerning`, `.tracking`, `.textCase(.uppercase)`; no fixed widths on text
  (Arabic and Italian strings run 30–40% longer than English).
- Test every screen with the scheme's App Language set to Arabic.

## 8. Accessibility

- Contrast: text uses only text tokens or strong semantic tokens on
  surfaces/soft washes — all AA. Text on a strong fill uses `Theme.onAccent`
  (or `color.readableForeground` for a categorical fill).
- Dynamic Type: only `Theme.Typography` / `MoneyText`; no fixed-height text
  containers; let `HStack`s wrap to `VStack` at accessibility sizes when needed
  (`ViewThatFits` or `@Environment(\.dynamicTypeSize).isAccessibilitySize`).
- 44×44 minimum tap targets; labels on icon-only buttons; `.isHeader` on
  section titles (built into `SectionHeader`); `.isSelected` on chips/tabs
  (built in).
- Reduce Motion: see §3.10. Reduce Transparency: no materials behind text.

## 9. Don'ts

- No raw hex, `Color(red:…)`, `.white`, `.black`, `Color.gray` in Features.
- No `.font(.system(size:))` for text, no `.fontWeight(.black)`, no rounded
  (`design: .rounded`) type — figures are serif, words are default.
- No paddings/spacings outside `Theme.Spacing`; no radii outside `Theme.Radius`.
- No capsules for badges, buttons or chips (`in: .capsule`) — rounded rects.
- No shadows on cards. No gradients. No glow. No `.opacity()` to fake a disabled
  or secondary colour — use the token.
- No deprecated tokens in migrated code (`Theme.lime/background/
  surfaceElevated/red/green/yellow/blue/redSurface` — the compiler warns).
- No colour-only status. No categorical colour on text.
- No `.preferredColorScheme`.
- No new `.swift` files (the committed Xcode project lists files explicitly).
  Screen-private helpers go in the screen's own file.

## 10. Migration checklist (apply per file)

1. Replace deprecated tokens: `background → canvas`, `surfaceElevated →
   surfaceMuted` (inside a card) or `surfaceRaised` (floating), `lime → accent`,
   `green → success`/`moneyIn`, `red → danger`/`moneyOut`, `yellow → warning`,
   `blue → info`, `redSurface → dangerSoft`. Zero deprecation warnings left in
   the file.
2. Remove every `.white`/`.black`/hex. Especially **`Theme.onAccent` text on a
   `.white` background** — invisible in light mode (see §11).
3. Replace every `.font(.system(size:…))`, `.font(.x.weight(.y))` with a
   `Theme.Typography` style; every money `Text(CurrencyFormat.string(…))` with
   `MoneyText`; hand-built `"+\(…)"`/`"−\(…)"` with `sign:`.
4. Replace numeric paddings/spacings with `Theme.Spacing`; screen gutter 20,
   section gap 28.
5. Replace `in: .capsule` badges/buttons/chips with `Pill`, `ActionButtonStyle`,
   `FilterChip`; hand-rolled cards (`.background(Theme.surface, in: .rect…)`)
   with `Card`/`.surfaceCard()`/`GroupedCard`; lists of separate cards with one
   `GroupedCard` + `RowDivider`s.
6. Replace ad-hoc hero blocks (solid `Theme.lime` fills) with `HeroCard`/
   `AccentCard`; stat blocks with `StatTile`; empty states with `EmptyState`.
7. Replace `.animation(...)` with `.themeAnimation(...)`; check Reduce Motion.
8. Replace `left/right`, `arrow.right`, `chevron.right`, `.kerning`,
   `.textCase(.uppercase)`.
9. Sheets: `.sheetChrome()`; screens: `.screenBackground()` +
   `.themedNavigationBar()`.
10. Run in light, dark, Arabic, and at the largest accessibility text size.
    Behaviour and logic unchanged; only the view layer moves.

## 11. Known light-mode hazards in unmigrated screens

These compile and work but look wrong in light mode until their owner migrates
them (fix first):

- `Features/Debts/DebtDetailView.swift` hero "% paid" chip: `onAccent` text on
  `.white` capsule (white on white).
- `Features/Journey/PlanRoadmap.swift` current-step node (`.white` fill +
  `onAccent` glyph) and the finish-flag chip (`.white` + `onAccent`).
- `Features/Transactions/SwipeToConfirm.swift` knob (`.white` + `onAccent`
  arrow) and the black text shadows.
- `Features/Board/BubbleCircle.swift` uses `onAccent` ink on categorical fills
  (white on yellow/pink in light) — use `tint.readableForeground`.
- Shared components still in Features: `PrimaryButton`, `SecondaryButton`,
  `FieldRow`, `StepProgress` (`Onboarding/OnboardingComponents.swift`) and
  `EmptyStateView` (`MainTabView.swift`). Their owners should re-implement them
  on `ActionButtonStyle`, `fieldChrome`, `ProgressBar` and `EmptyState`
  (keeping their signatures, since other screens call them).
- Heavy `.black.opacity(0.4+)` shadows (Documents, Journey export, toasts) —
  replace with `.elevation(.raised)`.
