import Foundation

/// A read value with the reader's confidence in it (0…1). `value` is nil when
/// the receipt did not show it or it could not be read.
public struct ReceiptField<Value: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
    public var value: Value?
    public var confidence: Double

    public init(value: Value?, confidence: Double) {
        self.value = value
        self.confidence = confidence
    }

    /// Flagged on the review screen. A missing value counts: an empty total
    /// needs the user's eye as much as a doubtful one.
    public var isLowConfidence: Bool {
        value == nil || confidence < ReceiptExtraction.lowConfidenceThreshold
    }

    private enum CodingKeys: String, CodingKey { case value, confidence }

    // Written by hand so a missing value is sent as `null`, as the contract
    // shows it, instead of the key being left out.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(confidence, forKey: .confidence)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Value.self, forKey: .value)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
    }
}

/// What the AI gateway read off a receipt: ReceiptExtraction v1 from
/// docs/RECEIPTS_CONTRACTS.md §5, as `receipts-extract` returns it and as it
/// is stored in `money_receipts.extraction`.
///
/// Money stays a decimal *string* here, exactly as sent; `ReceiptMoney`
/// turns it into `Decimal` where a figure is needed. Enumerations decode
/// leniently — a newer server adding a document type or a warning must not
/// make every receipt on an older app unreadable.
public struct ReceiptExtraction: Codable, Sendable, Hashable {

    /// The only version this decoder understands.
    public static let supportedVersion = "1"
    /// Below this a field is flagged for the user to check. The gateway uses
    /// the same line for its `low_confidence` warning.
    public static let lowConfidenceThreshold = 0.75

    public enum DocumentType: String, Codable, Sendable, CaseIterable {
        case receipt, invoice, scontrino, other

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = DocumentType(rawValue: raw) ?? .other
        }
    }

    public enum PaymentMethod: String, Codable, Sendable, CaseIterable {
        case card, cash, other

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = PaymentMethod(rawValue: raw) ?? .other
        }
    }

    public enum Scope: String, Codable, Sendable, CaseIterable {
        case business, personal
    }

    public enum Warning: String, Codable, Sendable, CaseIterable {
        case totalMismatch = "total_mismatch"
        case lowConfidence = "low_confidence"
        case notAReceipt = "not_a_receipt"
        case multipleCurrencies = "multiple_currencies"
    }

    public enum CategorySource: String, Codable, Sendable {
        case rule, model, `default`
    }

    public struct Merchant: Codable, Sendable, Hashable {
        public var name: ReceiptField<String>
        public var vatID: ReceiptField<String>
        public var address: ReceiptField<String>
        public var country: ReceiptField<String>

        private enum CodingKeys: String, CodingKey {
            case name, address, country
            case vatID = "vat_id"
        }
    }

    public struct TaxLine: Codable, Sendable, Hashable {
        /// Percentage as a decimal string: "22", "5.5".
        public var rate: String?
        public var taxable: String?
        public var tax: String?

        public init(rate: String?, taxable: String?, tax: String?) {
            self.rate = rate
            self.taxable = taxable
            self.tax = tax
        }

        // Nulls written out, matching the server's documents.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rate, forKey: .rate)
            try container.encode(taxable, forKey: .taxable)
            try container.encode(tax, forKey: .tax)
        }
    }

    public struct LineItem: Codable, Sendable, Hashable {
        public var description: String
        public var quantity: String?
        public var unitPrice: String?
        /// Signed: a discount printed as its own line is negative.
        public var amount: String?

        private enum CodingKeys: String, CodingKey {
            case description, quantity, amount
            case unitPrice = "unit_price"
        }

        public init(description: String, quantity: String?, unitPrice: String?, amount: String?) {
            self.description = description
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.amount = amount
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(description, forKey: .description)
            try container.encode(quantity, forKey: .quantity)
            try container.encode(unitPrice, forKey: .unitPrice)
            try container.encode(amount, forKey: .amount)
        }
    }

    public struct Payment: Codable, Sendable, Hashable {
        public var method: ReceiptField<PaymentMethod>
        public var cardLast4: ReceiptField<String>

        private enum CodingKeys: String, CodingKey {
            case method
            case cardLast4 = "card_last4"
        }
    }

    public struct Category: Codable, Sendable, Hashable {
        /// One of the user's category keys (contract §3).
        public var key: String
        public var confidence: Double
        /// `rule` when the user's own earlier correction decided it.
        public var source: CategorySource
    }

    public var version: String
    public var receiptID: UUID
    public var documentType: DocumentType
    public var merchant: Merchant
    public var merchantKey: String
    /// `YYYY-MM-DD`
    public var date: ReceiptField<String>
    /// `HH:MM`, 24-hour
    public var time: ReceiptField<String>
    /// ISO 4217
    public var currency: ReceiptField<String>
    public var total: ReceiptField<String>
    public var subtotal: ReceiptField<String>
    public var tip: ReceiptField<String>
    public var discount: ReceiptField<String>
    public var taxTotal: ReceiptField<String>
    public var taxLines: [TaxLine]
    public var lineItems: [LineItem]
    public var payment: Payment
    public var receiptNumber: ReceiptField<String>
    public var category: Category
    public var scopeSuggestion: Scope?
    /// The transaction this looks like a repeat of: same merchant, day and total.
    public var duplicateOf: UUID?
    public var warnings: [Warning]
    public var model: String
    public var promptVersion: String

    private enum CodingKeys: String, CodingKey {
        case version, merchant, date, time, currency, total, subtotal, tip, discount
        case payment, category, warnings, model
        case receiptID = "receipt_id"
        case documentType = "document_type"
        case merchantKey = "merchant_key"
        case taxTotal = "tax_total"
        case taxLines = "tax_lines"
        case lineItems = "line_items"
        case receiptNumber = "receipt_number"
        case scopeSuggestion = "scope_suggestion"
        case duplicateOf = "duplicate_of"
        case promptVersion = "prompt_version"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        receiptID = try c.decode(UUID.self, forKey: .receiptID)
        documentType = try c.decodeIfPresent(DocumentType.self, forKey: .documentType) ?? .other
        merchant = try c.decode(Merchant.self, forKey: .merchant)
        merchantKey = try c.decodeIfPresent(String.self, forKey: .merchantKey) ?? ""
        date = try c.decode(ReceiptField<String>.self, forKey: .date)
        time = try c.decode(ReceiptField<String>.self, forKey: .time)
        currency = try c.decode(ReceiptField<String>.self, forKey: .currency)
        total = try c.decode(ReceiptField<String>.self, forKey: .total)
        subtotal = try c.decode(ReceiptField<String>.self, forKey: .subtotal)
        tip = try c.decode(ReceiptField<String>.self, forKey: .tip)
        discount = try c.decode(ReceiptField<String>.self, forKey: .discount)
        taxTotal = try c.decode(ReceiptField<String>.self, forKey: .taxTotal)
        taxLines = try c.decodeIfPresent([TaxLine].self, forKey: .taxLines) ?? []
        lineItems = try c.decodeIfPresent([LineItem].self, forKey: .lineItems) ?? []
        payment = try c.decode(Payment.self, forKey: .payment)
        receiptNumber = try c.decode(ReceiptField<String>.self, forKey: .receiptNumber)
        category = try c.decode(Category.self, forKey: .category)
        scopeSuggestion = try? c.decodeIfPresent(Scope.self, forKey: .scopeSuggestion)
        duplicateOf = try? c.decodeIfPresent(UUID.self, forKey: .duplicateOf)
        // Unknown warnings are dropped, not fatal.
        let rawWarnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
        warnings = rawWarnings.compactMap(Warning.init(rawValue:))
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        promptVersion = try c.decodeIfPresent(String.self, forKey: .promptVersion) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(receiptID.uuidString.lowercased(), forKey: .receiptID)
        try c.encode(documentType, forKey: .documentType)
        try c.encode(merchant, forKey: .merchant)
        try c.encode(merchantKey, forKey: .merchantKey)
        try c.encode(date, forKey: .date)
        try c.encode(time, forKey: .time)
        try c.encode(currency, forKey: .currency)
        try c.encode(total, forKey: .total)
        try c.encode(subtotal, forKey: .subtotal)
        try c.encode(tip, forKey: .tip)
        try c.encode(discount, forKey: .discount)
        try c.encode(taxTotal, forKey: .taxTotal)
        try c.encode(taxLines, forKey: .taxLines)
        try c.encode(lineItems, forKey: .lineItems)
        try c.encode(payment, forKey: .payment)
        try c.encode(receiptNumber, forKey: .receiptNumber)
        try c.encode(category, forKey: .category)
        try c.encode(scopeSuggestion, forKey: .scopeSuggestion)
        try c.encode(duplicateOf?.uuidString.lowercased(), forKey: .duplicateOf)
        try c.encode(warnings, forKey: .warnings)
        try c.encode(model, forKey: .model)
        try c.encode(promptVersion, forKey: .promptVersion)
    }
}

// MARK: - Decoding

public enum ReceiptExtractionError: Error, Equatable {
    case unsupportedVersion(String)
}

public extension ReceiptExtraction {

    /// Decodes a gateway response or a stored `extraction`. Throws for a
    /// version this app does not know, rather than showing half a receipt.
    static func decode(_ data: Data) throws -> ReceiptExtraction {
        let extraction = try JSONDecoder().decode(ReceiptExtraction.self, from: data)
        guard extraction.version == supportedVersion else {
            throw ReceiptExtractionError.unsupportedVersion(extraction.version)
        }
        return extraction
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - Figures

public extension ReceiptExtraction {

    /// The receipt's currency, or nil when it could not be read.
    var currencyCode: String? { currency.value }

    var totalAmount: Decimal? { total.value.flatMap(ReceiptMoney.decimal(fromCanonical:)) }

    /// The tax paid: the printed tax total, else the sum of the tax lines.
    var taxAmount: Decimal? {
        if let printed = taxTotal.value.flatMap(ReceiptMoney.decimal(fromCanonical:)) { return printed }
        let lines = taxLines.compactMap { $0.tax.flatMap(ReceiptMoney.decimal(fromCanonical:)) }
        return lines.isEmpty ? nil : lines.reduce(0, +)
    }

    /// The purchase instant: the printed date, at the printed time when there
    /// is one (else midday, so a time-zone shift cannot move it to another
    /// day), in `timeZone`.
    func occurredAt(in timeZone: TimeZone = .current) -> Date? {
        guard let day = date.value else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        let clock = time.value?.split(separator: ":").compactMap { Int($0) } ?? []
        components.hour = clock.count == 2 ? clock[0] : 12
        components.minute = clock.count == 2 ? clock[1] : 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == parts[2]
        else { return nil }
        return date
    }
}

// MARK: - Confidence

public extension ReceiptExtraction {

    /// The fields the review screen shows, for flagging.
    enum FieldKey: String, CaseIterable, Sendable {
        case merchantName, vatID, date, time, currency, total, subtotal, tip, discount
        case taxTotal, paymentMethod, cardLast4, receiptNumber, category
    }

    func confidence(of key: FieldKey) -> Double {
        switch key {
        case .merchantName: merchant.name.confidence
        case .vatID: merchant.vatID.confidence
        case .date: date.confidence
        case .time: time.confidence
        case .currency: currency.confidence
        case .total: total.confidence
        case .subtotal: subtotal.confidence
        case .tip: tip.confidence
        case .discount: discount.confidence
        case .taxTotal: taxTotal.confidence
        case .paymentMethod: payment.method.confidence
        case .cardLast4: payment.cardLast4.confidence
        case .receiptNumber: receiptNumber.confidence
        case .category: category.source == .rule ? 1 : category.confidence
        }
    }

    private func hasValue(_ key: FieldKey) -> Bool {
        switch key {
        case .merchantName: merchant.name.value != nil
        case .vatID: merchant.vatID.value != nil
        case .date: date.value != nil
        case .time: time.value != nil
        case .currency: currency.value != nil
        case .total: total.value != nil
        case .subtotal: subtotal.value != nil
        case .tip: tip.value != nil
        case .discount: discount.value != nil
        case .taxTotal: taxTotal.value != nil
        case .paymentMethod: payment.method.value != nil
        case .cardLast4: payment.cardLast4.value != nil
        case .receiptNumber: receiptNumber.value != nil
        case .category: true
        }
    }

    /// Fields to highlight: anything read with confidence under the
    /// threshold, plus the four a transaction cannot do without (merchant,
    /// date, total, currency) when they are missing altogether. An optional
    /// field that simply is not on the receipt — no tip — is not flagged.
    var lowConfidenceFields: Set<FieldKey> {
        let required: Set<FieldKey> = [.merchantName, .date, .total, .currency]
        return Set(FieldKey.allCases.filter { key in
            if !hasValue(key) { return required.contains(key) }
            return confidence(of: key) < Self.lowConfidenceThreshold
        })
    }

    /// Whether the user should look before confirming, as opposed to a
    /// clean read they can accept at a glance.
    var needsAttention: Bool {
        !lowConfidenceFields.isEmpty || duplicateOf != nil || !warnings.isEmpty
    }
}
