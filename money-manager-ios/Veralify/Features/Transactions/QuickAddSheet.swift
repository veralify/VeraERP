import SwiftUI
import SwiftData

/// Keypad-driven entry sheet: pick a side, type an amount, tag it, swipe to commit.
struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var initialDirection: EntryDirection = .debit

    @State private var direction: EntryDirection
    @State private var digits = ""
    @State private var name = ""
    @State private var date = Date()
    @State private var category = EntryPresets.categories.first ?? "General"
    @State private var account = EntryPresets.accounts.first ?? "Cash"
    @State private var isNaming = false
    @State private var isCommitting = false

    init(initialDirection: EntryDirection = .debit) {
        self.initialDirection = initialDirection
        _direction = State(initialValue: initialDirection)
    }

    /// Typed digits as an amount. The keypad only produces digits and one
    /// separator, so this never needs the locale-tolerant parser.
    private var amount: Decimal {
        Decimal(string: digits.isEmpty ? "0" : digits, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    /// False once committed: the swipe control stays on screen while the form
    /// fades out, and a second swipe in that window saved the entry twice.
    private var canCommit: Bool { amount > 0 && !isCommitting }

    private var amountText: String {
        let whole = digits.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let grouped = (Decimal(string: String(whole.first ?? "0")) ?? 0)
            .formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(0)))
        if digits.contains(".") {
            let fraction = whole.count > 1 ? String(whole[1]) : ""
            return "\(grouped).\(fraction)"
        }
        return grouped
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                amountBlock
                Spacer(minLength: 0)
                chips
                // The keypad claims its full height first and the spacers
                // share what is left; on an SE-size screen the keys shorten
                // instead of pushing the swipe control off the bottom.
                keypad
                    .layoutPriority(1)
                SwipeToConfirm(
                    title: "Swipe to add entry",
                    accent: direction.accent,
                    enabled: canCommit,
                    onConfirm: commit
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .opacity(isCommitting ? 0 : 1)
            .scaleEffect(isCommitting ? 0.97 : 1)
        }
        .animation(.smooth(duration: 0.28), value: isCommitting)
        // Keypad ticks and a distinct tick when switching sides.
        .sensoryFeedback(.selection, trigger: digits)
        .sensoryFeedback(.selection, trigger: direction)
        .alert("Who's it for?", isPresented: $isNaming) {
            TextField("Name", text: $name)
            Button("Done") {}
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Theme.surface, in: .circle)
                    // A 44pt tap area around the 38pt circle.
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Cancel")

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(EntryDirection.allCases) { option in
                    Button {
                        direction = option
                    } label: {
                        Label(option.title, systemImage: option.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(direction == option ? Theme.textPrimary : Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                direction == option ? Theme.surfaceElevated : .clear,
                                in: .capsule
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(4)
            .background(Theme.surface, in: .capsule)

            Spacer(minLength: 8)
            // Mirrors the close button so the direction toggle stays centred.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var amountBlock: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(direction.sign)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(direction.accent)
                Text("€")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(amountText)
                    .font(.system(size: 62, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            }
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.2), value: digits)

            Button { isNaming = true } label: {
                Text(name.isEmpty ? "Who's it for?" : name)
                    .font(.body)
                    .foregroundStyle(name.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    // A long name stays one line rather than growing the
                    // block and squeezing the keypad.
                    .lineLimit(1)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 16)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DateField(label: "Date", date: $date, style: .chip)

                Menu {
                    ForEach(EntryPresets.categories, id: \.self) { option in
                        Button(option) { category = option }
                    }
                } label: {
                    ChipLabel(icon: "tag", text: category)
                }

                Menu {
                    ForEach(EntryPresets.accounts, id: \.self) { option in
                        Button(option) { account = option }
                    }
                } label: {
                    ChipLabel(icon: "creditcard", text: account)
                }
            }
            .padding(.horizontal, 16)
        }
        // The same 14pt as between the keypad and the swipe control, so the
        // three blocks at the bottom are evenly spaced.
        .padding(.vertical, 14)
    }

    private var keypad: some View {
        let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "⌫"]]
        return VStack(spacing: 10) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button { press(key) } label: {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                        .font(.system(size: 20, weight: .medium))
                                } else {
                                    Text(key).font(.system(size: 26, weight: .medium))
                                }
                            }
                            .foregroundStyle(Theme.textPrimary)
                            // 58pt where there is room, never below a 44pt
                            // tap target where there is not.
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 58)
                            .background(Theme.surfaceElevated, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Behaviour

    private func press(_ key: String) {
        switch key {
        case "⌫":
            if !digits.isEmpty { digits.removeLast() }
        case ".":
            // One separator only, and never as the leading character.
            if digits.isEmpty { digits = "0." } else if !digits.contains(".") { digits += "." }
        default:
            // Two decimal places is the most a currency amount can carry.
            if let dot = digits.firstIndex(of: "."), digits.distance(from: dot, to: digits.endIndex) > 2 { return }
            // Nine whole digits covers any household amount; beyond that the
            // figure overflows the display rather than meaning anything.
            if !digits.contains("."), digits.count >= 9 { return }
            if digits == "0" { digits = key } else { digits += key }
        }
    }

    private func commit() {
        guard canCommit else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        context.insert(
            TransactionRecord(
                occurredAt: date,
                name: trimmed.isEmpty ? category : trimmed,
                amount: amount,
                direction: direction,
                category: category,
                account: account
            )
        )
        try? context.save()

        // Fade the form out first, then hand the confirmation to the app level
        // so it can cover the full screen. A Task rather than DispatchQueue, so
        // the delay is cancelled if the sheet goes away first.
        isCommitting = true
        let committed = direction
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            QuickAddRouter.shared.pendingFlash = committed
            dismiss()
        }
    }
}

private struct ChipLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
            Text(text).font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

