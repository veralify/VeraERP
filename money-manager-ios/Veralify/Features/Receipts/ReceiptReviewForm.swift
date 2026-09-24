import SwiftUI
import SwiftData
import VeralifyCore

/// Everything the AI read off a receipt, editable, with the doubtful fields
/// marked — then one tap to save it as a transaction.
///
/// The AI's reading is a draft, never a record: nothing is saved until the
/// user confirms here. Fields read with confidence under 0.75 carry a
/// "Check" badge until the user edits them, so the eye goes to the figures
/// most likely to be wrong rather than to all of them.
struct ReceiptReviewForm: View {
    let record: ReceiptRecord
    let extraction: ReceiptExtraction

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var merchant: String
    @State private var date: Date
    @State private var total: String
    @State private var currency: String
    @State private var taxTotal: String
    @State private var subtotal: String
    @State private var tip: String
    @State private var discount: String
    @State private var vatID: String
    @State private var receiptNumber: String
    @State private var paymentMethod: ReceiptExtraction.PaymentMethod?
    @State private var category: String
    @State private var scope: EntryScope
    @State private var account: String
    @State private var lineItems: [EditableLineItem]
    @State private var taxLines: [EditableTaxLine]
    /// Fields still to check. Editing one clears its flag.
    @State private var flagged: Set<ReceiptExtraction.FieldKey>

    @State private var showsItems = false
    @State private var showsMore = false
    @State private var viewingPage: Int?
    @State private var isConfirmingDuplicate = false

    init(record: ReceiptRecord, extraction: ReceiptExtraction) {
        self.record = record
        self.extraction = extraction
        _merchant = State(initialValue: extraction.merchant.name.value ?? "")
        _date = State(initialValue: extraction.occurredAt() ?? record.createdAt)
        _total = State(initialValue: extraction.total.value ?? "")
        _currency = State(initialValue: extraction.currencyCode ?? AppSettings.currencyCode)
        _taxTotal = State(initialValue: extraction.taxTotal.value ?? "")
        _subtotal = State(initialValue: extraction.subtotal.value ?? "")
        _tip = State(initialValue: extraction.tip.value ?? "")
        _discount = State(initialValue: extraction.discount.value ?? "")
        _vatID = State(initialValue: extraction.merchant.vatID.value ?? "")
        _receiptNumber = State(initialValue: extraction.receiptNumber.value ?? "")
        _paymentMethod = State(initialValue: extraction.payment.method.value)
        _category = State(initialValue: extraction.category.key)
        _scope = State(initialValue: extraction.scopeSuggestion.flatMap { EntryScope(rawValue: $0.rawValue) } ?? .personal)
        // Cash is cash; a card is most often a debit card on the current
        // account. Either way the user can change it below.
        _account = State(initialValue: extraction.payment.method.value == .cash ? "Cash" : "Bank")
        _lineItems = State(initialValue: extraction.lineItems.map(EditableLineItem.init))
        _taxLines = State(initialValue: extraction.taxLines.map(EditableTaxLine.init))
        _flagged = State(initialValue: extraction.lowConfidenceFields)
    }

    // MARK: Derived

    private var currencyCode: String? {
        let code = currency.trimmingCharacters(in: .whitespaces).uppercased()
        return code.count == 3 && code.allSatisfy({ $0.isASCII && $0.isLetter }) ? code : nil
    }

    private var totalAmount: Decimal? { ReceiptMoney.parse(total, currency: currencyCode) }

    /// The printed tax total, else the sum of the tax lines.
    private var taxAmount: Decimal? {
        if let printed = ReceiptMoney.parse(taxTotal, currency: currencyCode) { return printed }
        let lines = taxLines.compactMap { ReceiptMoney.parse($0.tax, currency: currencyCode) }
        return lines.isEmpty ? nil : lines.reduce(0, +)
    }

    private var itemsTotal: Decimal? {
        let amounts = lineItems.map { ReceiptMoney.parse($0.amount, currency: currencyCode) }
        guard !amounts.isEmpty, amounts.allSatisfy({ $0 != nil }) else { return nil }
        return amounts.compactMap { $0 }.reduce(0, +)
    }

    /// Within a couple of cents: per-line rounding on a till can leave that.
    /// Discounts and tips printed separately are allowed for too.
    private func itemsMatchTotal(_ sum: Decimal) -> Bool {
        guard let total = totalAmount else { return false }
        let tolerance = Decimal(string: "0.02") ?? 0
        let off = (ReceiptMoney.parse(discount, currency: currencyCode) ?? 0)
        let on = (ReceiptMoney.parse(tip, currency: currencyCode) ?? 0)
        return [sum, sum - off, sum + on, sum - off + on].contains { abs($0 - total) <= tolerance }
    }

    private var canConfirm: Bool {
        !merchant.trimmingCharacters(in: .whitespaces).isEmpty
            && (totalAmount ?? 0) > 0
            && currencyCode != nil
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: currencyCode ?? AppSettings.currencyCode)
                .locale(Locale(identifier: "en_US"))
        )
    }

    private var pairLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ReceiptPageStrip(record: record) { viewingPage = $0 }
                notices
                essentials
                taxCard
                itemsCard
                moreCard
                PrimaryButton(title: "Save transaction", enabled: canConfirm) {
                    if extraction.duplicateOf != nil {
                        isConfirmingDuplicate = true
                    } else {
                        confirm()
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .dismissibleKeyboard()
        .fullScreenCover(item: Binding(
            get: { viewingPage.map(PageIndex.init) },
            set: { viewingPage = $0?.value }
        )) { index in
            ReceiptImageViewer(record: record, startPage: index.value)
        }
        .confirmationDialog(
            "Save it anyway?",
            isPresented: $isConfirmingDuplicate,
            titleVisibility: .visible
        ) {
            Button("Save anyway") { confirm() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A transaction from the same shop, on the same day and for the same amount is already saved.")
        }
    }

    // MARK: Notices

    @ViewBuilder
    private var notices: some View {
        if extraction.duplicateOf != nil {
            ReviewNotice(
                icon: "doc.on.doc.fill",
                tint: Theme.yellow,
                text: "This looks like a receipt you've already saved — same shop, day and total."
            )
        }
        if extraction.warnings.contains(.totalMismatch) {
            ReviewNotice(
                icon: "plusminus",
                tint: Theme.yellow,
                text: "The items don't add up to the total. Check the total against the photo."
            )
        }
        if extraction.warnings.contains(.multipleCurrencies) {
            ReviewNotice(
                icon: "dollarsign.arrow.circlepath",
                tint: Theme.yellow,
                text: "This receipt shows more than one currency. Make sure the total is the one you paid."
            )
        }
        if !flagged.isEmpty {
            ReviewNotice(
                icon: "exclamationmark.triangle.fill",
                tint: Theme.yellow,
                text: "Fields marked Check were hard to read. Tap a page above to compare."
            )
        }
    }

    // MARK: Essentials

    private var essentials: some View {
        VStack(spacing: 12) {
            ReviewField(
                label: "Merchant",
                text: $merchant,
                flagged: flagged.contains(.merchantName)
            ) { flagged.remove(.merchantName) }

            pairLayout {
                ReviewField(
                    label: "Total",
                    text: $total,
                    flagged: flagged.contains(.total),
                    keyboard: .decimalPad,
                    placeholder: "0.00"
                ) { flagged.remove(.total) }
                ReviewField(
                    label: "Currency",
                    text: $currency,
                    flagged: flagged.contains(.currency),
                    capitalization: .characters
                ) { flagged.remove(.currency) }
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 110)
            }

            VStack(alignment: .leading, spacing: 7) {
                if flagged.contains(.date) {
                    CheckBadge()
                }
                DateField(label: "Date", date: $date)
                    .onChange(of: date) { _, _ in flagged.remove(.date) }
            }

            categoryPicker

            VStack(alignment: .leading, spacing: 7) {
                Text("Scope")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Picker("Scope", selection: $scope) {
                    ForEach(EntryScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            menuRow(label: "Paid from", value: LocalizedStringKey(account)) {
                ForEach(EntryPresets.accounts, id: \.self) { option in
                    Button(LocalizedStringKey(option)) { account = option }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("Category")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if flagged.contains(.category) { CheckBadge() }
                Spacer(minLength: 4)
                if extraction.category.source == .rule && category == extraction.category.key {
                    Text("Your usual for this shop")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Menu {
                ForEach(ReceiptCategories.options(including: category), id: \.self) { key in
                    Button {
                        category = key
                        flagged.remove(.category)
                    } label: {
                        Label(ReceiptCategories.title(for: key), systemImage: ReceiptCategories.icon(for: key))
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ReceiptCategories.icon(for: category))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                    Text(ReceiptCategories.title(for: category))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner)
                        .strokeBorder(flagged.contains(.category) ? Theme.yellow : Theme.stroke, lineWidth: 1)
                )
            }
            .accessibilityLabel(Text("Category, \(ReceiptCategories.title(for: category))"))
        }
    }

    // MARK: Tax

    private var taxCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReviewField(
                label: "Tax (VAT / IVA)",
                text: $taxTotal,
                flagged: flagged.contains(.taxTotal),
                keyboard: .decimalPad,
                placeholder: "0.00"
            ) { flagged.remove(.taxTotal) }

            if !taxLines.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Rate").frame(width: 64, alignment: .leading)
                        Text("Net").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Tax").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)

                    ForEach($taxLines) { $line in
                        HStack(spacing: 8) {
                            CompactField(text: $line.rate, suffix: "%", keyboard: .decimalPad)
                                .frame(width: 64)
                            CompactField(text: $line.taxable, keyboard: .decimalPad)
                            CompactField(text: $line.tax, keyboard: .decimalPad)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    // MARK: Items

    @ViewBuilder
    private var itemsCard: some View {
        if !lineItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CollapsibleHeader(
                    title: "Items",
                    detail: "\(lineItems.count)",
                    isExpanded: $showsItems
                )

                if showsItems {
                    VStack(spacing: 8) {
                        ForEach($lineItems) { $item in
                            HStack(spacing: 8) {
                                CompactField(text: $item.description, keyboard: .default)
                                if !item.quantity.isEmpty {
                                    Text("×\(item.quantity)")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                CompactField(text: $item.amount, keyboard: .numbersAndPunctuation)
                                    .frame(width: 92)
                            }
                        }
                    }

                    if let sum = itemsTotal {
                        HStack {
                            Text("Items add up to")
                            Spacer(minLength: 8)
                            Text(money(sum))
                                .monospacedDigit()
                                .foregroundStyle(itemsMatchTotal(sum) ? Theme.green : Theme.yellow)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .animation(.snappy(duration: 0.22), value: showsItems)
        }
    }

    // MARK: More

    private var moreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            CollapsibleHeader(title: "More details", detail: nil, isExpanded: $showsMore)

            if showsMore {
                pairLayout {
                    ReviewField(
                        label: "Subtotal",
                        text: $subtotal,
                        flagged: flagged.contains(.subtotal),
                        keyboard: .decimalPad
                    ) { flagged.remove(.subtotal) }
                    ReviewField(
                        label: "Discount",
                        text: $discount,
                        flagged: flagged.contains(.discount),
                        keyboard: .decimalPad
                    ) { flagged.remove(.discount) }
                }
                pairLayout {
                    ReviewField(
                        label: "Tip",
                        text: $tip,
                        flagged: flagged.contains(.tip),
                        keyboard: .decimalPad
                    ) { flagged.remove(.tip) }
                    ReviewField(
                        label: "Receipt number",
                        text: $receiptNumber,
                        flagged: flagged.contains(.receiptNumber)
                    ) { flagged.remove(.receiptNumber) }
                }
                ReviewField(
                    label: "VAT number (P.IVA)",
                    text: $vatID,
                    flagged: flagged.contains(.vatID),
                    capitalization: .characters
                ) { flagged.remove(.vatID) }

                menuRow(label: "Payment", value: paymentTitle(paymentMethod)) {
                    ForEach(ReceiptExtraction.PaymentMethod.allCases, id: \.self) { method in
                        Button(paymentTitle(method)) {
                            paymentMethod = method
                            flagged.remove(.paymentMethod)
                        }
                    }
                }
                if let last4 = extraction.payment.cardLast4.value {
                    Text("Card ending \(last4)")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .animation(.snappy(duration: 0.22), value: showsMore)
    }

    private func paymentTitle(_ method: ReceiptExtraction.PaymentMethod?) -> LocalizedStringKey {
        switch method {
        case .card: "Card"
        case .cash: "Cash"
        case .other: "Other"
        case nil: "Not shown"
        }
    }

    private func menuRow<Options: View>(
        label: LocalizedStringKey,
        value: LocalizedStringKey,
        @ViewBuilder options: () -> Options
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            Menu {
                options()
            } label: {
                HStack {
                    Text(value)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.inner).strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
    }

    // MARK: Confirm

    /// Saves the transaction. The server marks the receipt confirmed when the
    /// transaction syncs (a trigger links the two); the phone shows it at once.
    private func confirm() {
        guard canConfirm, let amount = totalAmount, let code = currencyCode else { return }

        let transaction = TransactionRecord(
            occurredAt: date,
            name: merchant.trimmingCharacters(in: .whitespaces),
            amount: amount,
            direction: .debit,
            scope: scope,
            category: category,
            account: account
        )
        transaction.currency = code
        transaction.taxAmount = taxAmount
        transaction.receiptID = record.id
        transaction.sourceRaw = "receipt"
        context.insert(transaction)

        record.transactionID = transaction.id
        record.status = .confirmed

        // A corrected category is remembered for this merchant, so the next
        // receipt from it is filed the user's way before the AI is asked.
        if category != extraction.category.key {
            record.pendingRuleCategoryKey = category
            record.pendingRuleScopeRaw = scope.rawValue
        }

        try? context.save()
        ReceiptQueue.shared.kick()
        // Back to the list, where the receipt now shows as saved. (Not the
        // quick-add flash: it is presented from the tab shell, which cannot
        // present while this sheet is up.)
        dismiss()
    }
}

// MARK: - Editable rows

struct EditableLineItem: Identifiable {
    let id = UUID()
    var description: String
    var quantity: String
    var amount: String

    init(_ item: ReceiptExtraction.LineItem) {
        description = item.description
        quantity = item.quantity ?? ""
        amount = item.amount ?? ""
    }
}

struct EditableTaxLine: Identifiable {
    let id = UUID()
    var rate: String
    var taxable: String
    var tax: String

    init(_ line: ReceiptExtraction.TaxLine) {
        rate = line.rate ?? ""
        taxable = line.taxable ?? ""
        tax = line.tax ?? ""
    }
}

// MARK: - Pieces

/// A labelled field in the app's dark style that can carry a "Check" flag.
///
/// Its own rather than `FieldRow`, which has no way to mark a value as
/// doubtful. The flag clears on the first edit the user makes — not on the
/// value being set when the form opens, hence the focus check.
struct ReviewField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var flagged: Bool = false
    var keyboard: UIKeyboardType = .default
    var placeholder: LocalizedStringKey = ""
    var capitalization: TextInputAutocapitalization = .sentences
    var onEdit: () -> Void = {}

    @FocusState private var isFocused: Bool

    private var border: Color {
        if isFocused { return Theme.lime.opacity(0.6) }
        return flagged ? Theme.yellow : Theme.stroke
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if flagged { CheckBadge() }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($isFocused)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surfaceElevated, in: .rect(cornerRadius: Theme.Radius.inner))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner)
                        .strokeBorder(border, lineWidth: flagged && !isFocused ? 1.5 : 1)
                )
                .onChange(of: text) { _, _ in
                    if isFocused { onEdit() }
                }
                .accessibilityHint(flagged ? Text("Hard to read on the receipt. Check it.") : Text(""))
        }
    }
}

/// The "Check" marker on a doubtful field.
struct CheckBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Check")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Theme.onAccent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Theme.yellow, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// A small inline field for table rows (tax lines, items).
struct CompactField: View {
    @Binding var text: String
    var suffix: String?
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack(spacing: 2) {
            TextField("", text: $text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .monospacedDigit()
            if let suffix {
                Text(verbatim: suffix).foregroundStyle(Theme.textTertiary)
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Theme.surfaceElevated, in: .rect(cornerRadius: 10))
    }
}

/// A tappable card header that shows or hides what is under it.
struct CollapsibleHeader: View {
    let title: LocalizedStringKey
    let detail: String?
    @Binding var isExpanded: Bool

    var body: some View {
        Button { isExpanded.toggle() } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let detail {
                    Text(verbatim: detail)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressableRow)
        .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
    }
}

/// A one-line notice above the form.
struct ReviewNotice: View {
    let icon: String
    let tint: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.inner))
        .accessibilityElement(children: .combine)
    }
}
