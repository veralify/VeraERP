import SwiftUI
import VeralifyCore

/// Navigation value for the quick split calculator.
struct SplitRoute: Hashable {}

// MARK: - Payment handles

/// The handles someone can be paid back on, kept in `UserDefaults`.
///
/// A `DynamicProperty` rather than a plain struct, so the `@AppStorage`
/// wrappers inside it still drive view updates when it is held as a property of
/// a view. Nothing here leaves the device until the user shares a message.
struct PaymentProfile: DynamicProperty {
    enum Key {
        static let venmo   = "payment.handle.venmo"
        static let cashApp = "payment.handle.cashapp"
        static let zelle   = "payment.handle.zelle"
        static let payPal  = "payment.handle.paypal"
        static let other   = "payment.handle.other"
    }

    @AppStorage(Key.venmo)   var venmo   = ""
    @AppStorage(Key.cashApp) var cashApp = ""
    @AppStorage(Key.zelle)   var zelle   = ""
    @AppStorage(Key.payPal)  var payPal  = ""
    @AppStorage(Key.other)   var other   = ""

    struct Handle: Identifiable {
        let id: String
        let label: String
        let value: String
        /// What the service expects in front of the handle, added on display so
        /// the user need not remember to type it.
        let prefix: String

        var display: String {
            value.hasPrefix(prefix) || prefix.isEmpty ? value : prefix + value
        }
    }

    /// Only the handles that were actually filled in, in the order they read
    /// best in a message.
    var filled: [Handle] {
        let all = [
            Handle(id: Key.payPal,  label: String(localized: "PayPal"),   value: payPal,  prefix: ""),
            Handle(id: Key.venmo,   label: String(localized: "Venmo"),    value: venmo,   prefix: "@"),
            Handle(id: Key.cashApp, label: String(localized: "Cash App"), value: cashApp, prefix: "$"),
            Handle(id: Key.zelle,   label: String(localized: "Zelle"),    value: zelle,   prefix: ""),
            Handle(id: Key.other,   label: String(localized: "Other"),    value: other,   prefix: "")
        ]
        return all.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var isEmpty: Bool { filled.isEmpty }
}

// MARK: - The split itself

/// A bill, a tip and a number of people — and what each person owes.
///
/// Money is `Decimal`, not `Double`. A tenth of a cent of floating-point error
/// is invisible until it is the difference between the shares adding up to the
/// bill and falling a cent short, and this app settled that question in
/// `Money.swift` already.
struct SplitResult {
    let bill: Decimal
    let tipPercent: Int
    let people: Int

    var tip: Decimal { Money.rounded(bill * Decimal(tipPercent) / 100) }
    var total: Decimal { bill + tip }

    /// Per-person shares, summing exactly to `total`. The first share carries
    /// any odd cent, so three people splitting €100 pay 33.34 / 33.33 / 33.33
    /// rather than 33.33 each and leaving a cent on the table.
    var shares: [Decimal] { FamilySplit.equalShares(of: total, ways: people) }

    var largestShare: Decimal { shares.max() ?? 0 }
    var smallestShare: Decimal { shares.min() ?? 0 }
    var isEven: Bool { largestShare == smallestShare }

    /// How many people pay the higher amount when it does not divide evenly.
    var payingExtra: Int { shares.filter { $0 == largestShare }.count }

    var isValid: Bool { bill > 0 && people > 0 }

    /// The message that goes to the share sheet.
    ///
    /// Written the way someone would actually text it — no headings, no
    /// bullets, nothing that reads as generated. Handles are listed only when
    /// the user has saved some.
    func message(profile: PaymentProfile) -> String {
        var lines: [String] = []

        if tipPercent > 0 {
            lines.append(String(
                localized: "\(CurrencyFormat.string(total)) all in, tip included."
            ))
        } else {
            lines.append(String(localized: "\(CurrencyFormat.string(total)) all in."))
        }

        if people > 1 {
            if isEven {
                lines.append(String(
                    localized: "That's \(CurrencyFormat.string(largestShare)) each, \(people) ways."
                ))
            } else {
                // Saying it outright beats letting someone notice they were
                // charged a cent more than the person next to them.
                lines.append(String(
                    localized: "That's \(CurrencyFormat.string(smallestShare)) each — \(payingExtra) of us round up to \(CurrencyFormat.string(largestShare)) so it comes out exact."
                ))
            }
        }

        let handles = profile.filled
        if !handles.isEmpty {
            lines.append("")
            lines.append(String(localized: "Pay me back:"))
            for handle in handles {
                lines.append("\(handle.label): \(handle.display)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Screen

/// Split a bill, then send it to whoever owes you.
///
/// Deliberately offline: no session, no server, no accounts. The result leaves
/// the device only when the user taps share, and only into whichever app they
/// pick.
struct QuickSplitView: View {
    private static let tipOptions = [0, 15, 18, 20, 25]

    @AppStorage("split.lastTipPercent") private var storedTip = 18

    @State private var amount = ""
    @State private var isCustomTip = false
    @State private var customTip = ""
    @State private var people = 2
    @State private var isEditingHandles = false

    @State private var isScanning = false
    @State private var scanNote: ScanNote?

    /// What the last scan produced, so the screen can say where the figure came
    /// from instead of silently changing a number the user typed.
    private struct ScanNote: Identifiable {
        enum Kind { case confident, guessed, failed }
        let id = UUID()
        let kind: Kind
        let detail: String
    }

    private var profile = PaymentProfile()

    private var tipPercent: Int {
        guard isCustomTip else { return storedTip }
        return min(max(Int(customTip) ?? 0, 0), 100)
    }

    private var split: SplitResult {
        SplitResult(
            bill: AmountParser.parse(amount) ?? 0,
            tipPercent: tipPercent,
            people: people
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    resultCard
                    scanSection
                    billSection
                    tipSection
                    peopleSection
                    breakdownSection
                    handlesSection
                    shareButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 108)
            }
            .scrollIndicators(.hidden)
            .dismissibleKeyboard()
        }
        .navigationTitle("Split a bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isEditingHandles) {
            PaymentHandlesSheet().presentationBackground(Theme.background)
        }
        .fullScreenCover(isPresented: $isScanning) {
            ReceiptScanner { result in
                isScanning = false
                apply(result)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Result

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Eyebrow held tight to the figure, as on `AccentCard` and the
            // family summary, so the three hero cards share one rhythm.
            VStack(alignment: .leading, spacing: 2) {
                Text(people == 1 ? "You pay" : "Each person pays")
                    .font(.caption.weight(.bold))
                    .kerning(0.5)
                    .foregroundStyle(Theme.onAccent.opacity(0.7))

                Text(CurrencyFormat.string(split.isValid ? split.largestShare : 0))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Theme.onAccent)
                    .contentTransition(.numericText())
            }

            if split.isValid {
                Text(split.tipPercent > 0
                     ? "\(CurrencyFormat.string(split.total)) total, \(split.tipPercent)% tip included"
                     : "\(CurrencyFormat.string(split.total)) total")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Enter the bill to see the split.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime, in: .rect(cornerRadius: Theme.Radius.card))
        .animation(.snappy(duration: 0.25), value: split.largestShare)
        .accessibilityElement(children: .combine)
    }

    // MARK: Scanning

    @ViewBuilder
    private var scanSection: some View {
        VStack(spacing: 10) {
            Button { isScanning = true } label: {
                Label("Scan receipt", systemImage: "doc.viewfinder")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surfaceElevated, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .disabled(!ReceiptScanner.isSupported)
            .opacity(ReceiptScanner.isSupported ? 1 : 0.5)

            if !ReceiptScanner.isSupported {
                // True on every simulator, which is where this will first be
                // tried. Saying so beats a button that does nothing.
                // Centred like the hint it replaces, so the caption under the
                // button does not jump sides between the two states.
                Text("Scanning needs a camera, so it only works on a device.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            } else if let note = scanNote {
                scanNoteRow(note)
            } else {
                Text("Reads the total off the receipt. Everything stays on your phone.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func scanNoteRow(_ note: ScanNote) -> some View {
        let tint: Color = switch note.kind {
        case .confident: Theme.green
        case .guessed:   Theme.yellow
        case .failed:    Theme.red
        }

        // Baseline-aligned: the note can run to two or three lines, and a
        // centred icon then floated beside the middle of the paragraph
        // instead of marking its first line.
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: note.kind == .confident ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(note.detail)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    /// Fills the bill field from a scan, and always says where the figure came
    /// from. OCR on a crumpled thermal receipt is good, not certain, and a
    /// number that appears without explanation is a number nobody checks.
    private func apply(_ result: Result<[String], Error>) {
        switch result {
        case .failure(let error):
            if case ReceiptScanError.cancelled = error { return }
            scanNote = ScanNote(
                kind: .failed,
                detail: String(localized: "Couldn't read that one. Type the total instead.")
            )

        case .success(let lines):
            guard let total = ReceiptParser.findTotal(in: lines) else {
                scanNote = ScanNote(
                    kind: .failed,
                    detail: String(localized: "No total found on that receipt. Type it instead.")
                )
                return
            }

            amount = total.amount.editableText
            scanNote = switch total.basis {
            case .keyword:
                ScanNote(
                    kind: .confident,
                    detail: String(localized: "Read \(CurrencyFormat.string(total.amount)) from the receipt. Check it before you share.")
                )
            case .largestAmount:
                ScanNote(
                    kind: .guessed,
                    detail: String(localized: "No total line found, so this is the largest amount on the receipt. Worth checking.")
                )
            }
        }
    }

    // MARK: Inputs

    private var billSection: some View {
        VStack(spacing: 14) {
            FieldRow(
                label: "Bill total",
                placeholder: "0.00",
                text: $amount,
                keyboard: .decimalPad
            )
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tip")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Self.tipOptions, id: \.self) { option in
                        tipChip(
                            label: option == 0 ? String(localized: "None") : "\(option)%",
                            isOn: !isCustomTip && storedTip == option
                        ) {
                            isCustomTip = false
                            storedTip = option
                        }
                    }
                    tipChip(label: String(localized: "Custom"), isOn: isCustomTip) {
                        isCustomTip = true
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            if isCustomTip {
                FieldRow(
                    label: "Custom tip %",
                    placeholder: "0",
                    text: $customTip,
                    keyboard: .numberPad
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func tipChip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isOn ? Theme.lime : Theme.surfaceElevated, in: .capsule)
        }
        .buttonStyle(.pressable)
    }

    private var peopleSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Splitting between")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(people) people")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            // The stepper keeps its full width; the label wraps beside it
            // at large text sizes instead of squeezing the − and + buttons.
            Stepper(value: $people, in: 1...50) { EmptyView() }
                .labelsHidden()
                .tint(Theme.lime)
                .fixedSize()
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    // MARK: Breakdown

    @ViewBuilder
    private var breakdownSection: some View {
        if split.isValid {
            VStack(spacing: 12) {
                SectionHeader(title: "Breakdown") { EmptyView() }

                GroupedCard {
                    breakdownRow("Bill", CurrencyFormat.string(split.bill))
                    if split.tipPercent > 0 {
                        RowDivider()
                        breakdownRow("Tip \(split.tipPercent)%", CurrencyFormat.string(split.tip))
                    }
                    RowDivider()
                    breakdownRow("Total", CurrencyFormat.string(split.total), emphasised: true)
                }

                if !split.isEven {
                    // The shares cannot be equal, so the screen says which ones
                    // differ rather than showing one figure that is wrong for
                    // somebody.
                    Text("\(split.payingExtra) of \(split.people) pay \(CurrencyFormat.string(split.largestShare)), the rest pay \(CurrencyFormat.string(split.smallestShare)). That way it adds up to the bill exactly.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func breakdownRow(_ label: LocalizedStringKey, _ value: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(emphasised ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(emphasised ? Theme.textPrimary : Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(emphasised ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, 13)
    }

    // MARK: Handles

    private var handlesSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Pay me back") {
                Button("Edit") { isEditingHandles = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.lime)
                    // A one-word button; the hit area reaches 44pt without
                    // the header growing to match.
                    .contentShape(Rectangle().inset(by: -12))
            }

            if profile.isEmpty {
                Button { isEditingHandles = true } label: {
                    Text("Add your Venmo, PayPal or Cash App and they'll be included in the message.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
                }
                .buttonStyle(.pressable)
            } else {
                GroupedCard {
                    ForEach(Array(profile.filled.enumerated()), id: \.element.id) { index, handle in
                        if index > 0 { RowDivider() }
                        HStack(alignment: .firstTextBaseline) {
                            // The service name stays whole; a long handle
                            // truncates in its middle instead.
                            Text(handle.label)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .layoutPriority(1)
                            Spacer(minLength: 8)
                            Text(handle.display)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 13)
                    }
                }
            }
        }
    }

    // MARK: Share

    @ViewBuilder
    private var shareButton: some View {
        let text = split.message(profile: profile)

        ShareLink(item: text) {
            Label("Share the split", systemImage: "square.and.arrow.up")
                .font(.body.weight(.bold))
                .foregroundStyle(split.isValid ? Theme.lime.readableForeground : Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(split.isValid ? Theme.lime : Theme.surfaceElevated, in: .capsule)
        }
        .buttonStyle(.pressable)
        .disabled(!split.isValid)
        .accessibilityHint("Opens the share sheet with the split written out")
    }
}

// MARK: - Handles editor

/// Saving the handles. Plain text fields: a handle is whatever the service
/// calls it, and guessing at a format only gets in the way.
struct PaymentHandlesSheet: View {
    @Environment(\.dismiss) private var dismiss
    private var profile = PaymentProfile()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            FieldRow(label: "PayPal.me", placeholder: "paypal.me/yourname", text: profile.$payPal)
                            FieldRow(label: "Venmo", placeholder: "yourhandle", text: profile.$venmo)
                            FieldRow(label: "Cash App", placeholder: "yourcashtag", text: profile.$cashApp)
                            FieldRow(label: "Zelle", placeholder: "Phone or email", text: profile.$zelle)
                            FieldRow(label: "Anything else", placeholder: "IBAN, Revolut, a note", text: profile.$other)
                        }
                        .padding(16)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))

                        Text("Saved on this device and only ever sent when you share a split.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        PrimaryButton(title: "Done", enabled: true) { dismiss() }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .dismissibleKeyboard()
            }
            .navigationTitle("Payment handles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
