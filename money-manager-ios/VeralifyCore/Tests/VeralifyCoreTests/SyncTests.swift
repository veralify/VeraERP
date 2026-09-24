import Testing
import Foundation
@testable import VeralifyCore

private var rome: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    return calendar
}

private let user = UUID(uuidString: "91000000-0000-0000-0000-000000000001")!
private let rowID = UUID(uuidString: "92000000-0000-0000-0000-00000000000A")!

private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, calendar: Calendar = rome) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

/// What the server would send back for a pushed row: the pushed columns plus
/// its own bookkeeping.
private func echoed(_ row: SyncRow, seq: Int64 = 7) -> SyncRow {
    row.merging([
        "sync_seq": .int(seq),
        "created_at": .string("2026-09-25T10:00:00.123456+00:00"),
        "updated_at": .string("2026-09-25T10:00:00.123456+00:00")
    ]) { $1 }
}

@Suite("Sync wire formats")
struct SyncFormatTests {
    @Test("Money is plain decimal text in both directions")
    func money() {
        #expect(SyncFormat.decimalString(Decimal(string: "12.50")!) == "12.5")
        #expect(SyncFormat.decimalString(Decimal(string: "2985.72")!) == "2985.72")
        #expect(SyncFormat.decimalString(Decimal(string: "-0.01")!) == "-0.01")
        #expect(SyncFormat.decimalString(Decimal(1_000_000)) == "1000000")
        #expect(SyncFormat.decimal(from: "12.50") == Decimal(string: "12.5"))
        #expect(SyncFormat.decimal(from: "0.1")! + SyncFormat.decimal(from: "0.2")! == Decimal(string: "0.3"))
    }

    @Test("Money parsing rejects anything that is not wholly a number")
    func strictMoney() {
        for bad in ["", "12abc", "1,50", "1.2.3", ".5", "5.", "1e3", "€5", "NaN"] {
            #expect(SyncFormat.decimal(from: bad) == nil, "\(bad) should not parse")
        }
    }

    @Test("Calendar dates use the user's calendar, not UTC")
    func calendarDates() {
        // 00:30 in Rome on 1 October is still 30 September in UTC.
        let justAfterMidnight = day(2026, 10, 1).addingTimeInterval(30 * 60)
        #expect(SyncFormat.calendarDate(justAfterMidnight, calendar: rome) == "2026-10-01")
        #expect(SyncFormat.monthDate(justAfterMidnight, calendar: rome) == "2026-10-01")
        #expect(SyncFormat.monthDate(day(2026, 2, 17), calendar: rome) == "2026-02-01")
        #expect(SyncFormat.date(fromCalendarDate: "2026-10-01", calendar: rome) == day(2026, 10, 1))
        #expect(SyncFormat.date(fromCalendarDate: "2026-02-30", calendar: rome) == nil)
        #expect(SyncFormat.date(fromCalendarDate: "yesterday", calendar: rome) == nil)
    }

    @Test("Instants read what Postgres sends, whatever the precision and zone")
    func instants() {
        let expected = Date(timeIntervalSince1970: 1_790_330_645.123)
        #expect(abs(SyncFormat.date(fromInstant: "2026-09-25T10:04:05.123456+00:00")!.timeIntervalSince(expected)) < 0.001)
        #expect(abs(SyncFormat.date(fromInstant: "2026-09-25 12:04:05.123+02:00")!.timeIntervalSince(expected)) < 0.001)
        #expect(abs(SyncFormat.date(fromInstant: "2026-09-25T10:04:05.123Z")!.timeIntervalSince(expected)) < 0.001)
        #expect(SyncFormat.date(fromInstant: "2026-09-25T10:04:05Z") == Date(timeIntervalSince1970: 1_790_330_645))
        #expect(SyncFormat.date(fromInstant: "2026-09-25T10:04:05") == nil, "an instant without a zone is ambiguous")
        #expect(SyncFormat.date(fromInstant: "not a date") == nil)
    }

    @Test("An instant survives a round trip through the wire format exactly")
    func instantRoundTrip() {
        let original = Date(timeIntervalSince1970: 1_790_330_645.123_789)
        let text = SyncFormat.instant(original)
        #expect(text == "2026-09-25T10:04:05.124Z")
        let back = SyncFormat.date(fromInstant: text)!
        #expect(SyncFormat.instant(back) == text)
    }
}

@Suite("Sync rows")
struct SyncRowTests {
    @Test("Every table's encoded row carries exactly its columns", arguments: SyncTable.allCases.filter { !$0.isPullOnly })
    func columnSets(table: SyncTable) {
        let keys = Set(sampleRow(for: table).keys)
        var expected = Set(table.columns).union(["user_id", "deleted_at"])
        if table.hasID { expected.insert("id") }
        #expect(keys == expected)
    }

    @Test("Pulls cast numeric columns to text and carry the cursor")
    func selectLists() {
        #expect(SyncTable.debts.selectList.contains("balance::text"))
        #expect(SyncTable.debts.selectList.contains("minimum_payment::text"))
        #expect(!SyncTable.debts.selectList.contains("priority::text"))
        #expect(SyncTable.transactions.selectList.hasPrefix("id,"))
        #expect(SyncTable.transactions.selectList.hasSuffix("sync_seq"))
        #expect(SyncTable.settings.selectList == "key,value,deleted_at,updated_at,sync_seq")
        #expect(SyncTable.settings.conflictTarget == "user_id,key")
        #expect(SyncTable.income.conflictTarget == "id")
    }

    @Test("Parents are pulled before the rows that point at them")
    func order() {
        let order = SyncTable.allCases
        #expect(order.firstIndex(of: .debts)! < order.firstIndex(of: .debtPayments)!)
        #expect(order.firstIndex(of: .income)! < order.firstIndex(of: .incomeActuals)!)
    }

    @Test("Money is sent as a string, never a number")
    func moneyIsText() {
        let row = DebtRow(
            id: rowID, localID: 3, name: "Intesa", balance: Decimal(string: "2985.72")!, apr: Decimal(string: "11.49")!,
            minimumPayment: 105, extraPayment: 0, dueDay: 1, priority: 3
        ).encoded(userID: user)
        #expect(row["balance"] == .string("2985.72"))
        #expect(row["apr"] == .string("11.49"))
        #expect(row["local_id"] == .int(3))
        #expect(row["user_id"] == .string("91000000-0000-0000-0000-000000000001"))
        #expect(row["id"] == .string("92000000-0000-0000-0000-00000000000a"), "ids go out lower-case, as Postgres returns them")
        let json = String(decoding: try! SyncJSON.data(for: [row]), as: UTF8.self)
        #expect(json.contains("\"balance\":\"2985.72\""))
    }

    @Test("A transaction maps direction, date and category the server's way")
    func transaction() throws {
        let occurred = day(2026, 10, 1).addingTimeInterval(30 * 60)
        let row = TransactionRow(
            id: rowID, occurredAt: occurred, merchant: "Esselunga", amount: Decimal(string: "12.50")!, isCredit: false,
            categoryKey: "groceries", account: "Cash", notes: "", currency: "gbp", taxAmount: Decimal(string: "2.25")!,
            scope: "business", source: "receipt", receiptID: rowID
        ).encoded(userID: user, calendar: rome)
        #expect(row["direction"] == .string("expense"))
        #expect(row["transaction_date"] == .string("2026-10-01"))
        #expect(row["currency"] == .string("GBP"))
        #expect(row["tax_amount"] == .string("2.25"))
        #expect(row["source"] == .string("receipt"))

        let back = try TransactionRow(row: echoed(row), calendar: rome)
        #expect(back.encoded(userID: user, calendar: rome) == row)
    }

    @Test("A web row with only a date lands at midday, on that day")
    func dateOnlyTransaction() throws {
        var row = sampleRow(for: .transactions)
        row["occurred_at"] = .null
        row["transaction_date"] = .string("2026-03-29")
        let decoded = try TransactionRow(row: echoed(row), calendar: rome)
        #expect(SyncFormat.calendarDate(decoded.occurredAt, calendar: rome) == "2026-03-29")
    }

    @Test("Unknown enum values are sent as the safe default, not rejected by the server")
    func sanitisedEnums() {
        let transaction = TransactionRow(
            id: rowID, occurredAt: .now, merchant: "x", amount: -3, isCredit: true, categoryKey: "other",
            account: "Cash", notes: "", currency: "euro", taxAmount: nil, scope: "family", source: "magic", receiptID: nil
        ).encoded(userID: user, calendar: rome)
        #expect(transaction["scope"] == .string("personal"))
        #expect(transaction["source"] == .string("manual"))
        #expect(transaction["currency"] == .string("EUR"))
        #expect(transaction["amount"] == .string("0"))

        let loss = LossRow(id: rowID, date: .now, amount: 5, reason: "aliens", note: "").encoded(userID: user, calendar: rome)
        #expect(loss["reason"] == .string("other"))
    }

    @Test("Every row decodes back to what was pushed", arguments: SyncTable.allCases.filter { $0.hasID && !$0.isPullOnly })
    func roundTrip(table: SyncTable) throws {
        let row = sampleRow(for: table)
        let pulled = echoed(row)
        let meta = try SyncMeta(row: pulled, table: table)
        #expect(meta.id == "92000000-0000-0000-0000-00000000000a")
        #expect(meta.syncSeq == 7)
        #expect(!meta.isDeleted)
        #expect(try reencode(pulled, table: table) == row)
    }

    @Test("A wrong value fails the row instead of being defaulted")
    func strictDecoding() {
        var row = sampleRow(for: .income)
        row["amount"] = .string("lots")
        #expect(throws: SyncDecodeError.self) { try IncomeRow(row: row) }
        row = sampleRow(for: .income)
        row["active"] = .int(1)
        #expect(throws: SyncDecodeError.self) { try IncomeRow(row: row) }
    }

    @Test("Settings go out as the web's key/value rows and read back")
    func settings() throws {
        let settings = SettingsRows(targetMonths: 16, startDate: day(2026, 9, 1), payoffStrategy: "smallestBalance", homeCurrency: "EUR")
        let rows = settings.encoded(userID: user, calendar: rome)
        #expect(rows.count == 4)
        #expect(rows["targetMonths"]?["value"] == .string("16"))
        #expect(rows["startDate"]?["value"] == .string("2026-09-01"))
        #expect(rows["startDate"]?["key"] == .string("startDate"))

        var copy = SettingsRows(targetMonths: 1, startDate: .distantPast, payoffStrategy: "highestInterest", homeCurrency: "GBP")
        for (key, row) in rows { copy.apply(key: key, value: row["value"]!.stringValue!, calendar: rome) }
        #expect(copy == settings)
        let rejectedMonths = copy.apply(key: "targetMonths", value: "9999", calendar: rome)
        let rejectedDate = copy.apply(key: "startDate", value: "soon", calendar: rome)
        let rejectedStrategy = copy.apply(key: "payoffStrategy", value: "vibes", calendar: rome)
        #expect(!rejectedMonths && !rejectedDate && !rejectedStrategy)
        #expect(copy == settings, "bad values leave the setting as it was")
    }

    @Test("JSON bodies decode booleans, integers, text and nulls exactly")
    func jsonDecoding() throws {
        let body = #"[{"id":"92000000-0000-0000-0000-00000000000a","active":true,"payday":28,"amount":"1750.00","deleted_at":null,"image_paths":["a/1.jpg"]}]"#
        let rows = try SyncJSON.rows(from: Data(body.utf8))
        #expect(rows[0]["active"] == .bool(true))
        #expect(rows[0]["payday"] == .int(28))
        #expect(rows[0]["amount"] == .string("1750.00"))
        #expect(rows[0]["deleted_at"] == .null)
        #expect(rows[0]["image_paths"] == .strings(["a/1.jpg"]))
    }

    @Test("A fingerprint does not depend on key order")
    func fingerprints() {
        let a: SyncRow = ["a": .int(1), "b": .string("x")]
        var b: SyncRow = ["b": .string("x")]
        b["a"] = .int(1)
        #expect(SyncJSON.fingerprint(of: a) == SyncJSON.fingerprint(of: b))
        #expect(SyncJSON.fingerprint(of: a) != SyncJSON.fingerprint(of: ["a": .int(2), "b": .string("x")]))
    }

    private func reencode(_ row: SyncRow, table: SyncTable) throws -> SyncRow {
        switch table {
        case .categories: try CategoryRow(row: row).encoded(userID: user)
        case .merchantRules: try MerchantRuleRow(row: row).encoded(userID: user)
        case .income: try IncomeRow(row: row).encoded(userID: user)
        case .incomeActuals: try IncomeActualRow(row: row, calendar: rome).encoded(userID: user, calendar: rome)
        case .expenses: try ExpenseRow(row: row).encoded(userID: user)
        case .debts: try DebtRow(row: row).encoded(userID: user)
        case .debtPayments: try DebtPaymentRow(row: row, calendar: rome).encoded(userID: user, calendar: rome)
        case .transactions: try TransactionRow(row: row, calendar: rome).encoded(userID: user, calendar: rome)
        case .losses: try LossRow(row: row, calendar: rome).encoded(userID: user, calendar: rome)
        case .snapshots: try SnapshotRow(row: row, calendar: rome).encoded(userID: user, calendar: rome)
        case .budgets: try BudgetRow(row: row).encoded(userID: user)
        case .settings, .receipts: row
        }
    }

    @Test("A pulled receipt keeps its reading verbatim and its pages in order")
    func receipt() throws {
        #expect(SyncTable.receipts.selectList.contains("extraction::text"))
        #expect(SyncTable.receipts.isPullOnly)
        let body = #"[{"id":"92000000-0000-0000-0000-00000000000a","image_paths":["u/r/1.jpg","u/r/2.jpg"],"source":"email","status":"extracted","extraction":"{\"version\": \"1\", \"total\": {\"value\": \"12.50\"}}","transaction_id":null,"deleted_at":null,"created_at":"2026-09-25T10:00:00+00:00","updated_at":"2026-09-25T10:00:00+00:00","sync_seq":9}]"#
        let row = try SyncJSON.rows(from: Data(body.utf8))[0]
        let receipt = try ReceiptRow(row: row)
        #expect(receipt.imagePaths == ["u/r/1.jpg", "u/r/2.jpg"])
        #expect(receipt.source == "email")
        #expect(receipt.status == "extracted")
        #expect(receipt.extractionJSON?.contains("\"12.50\"") == true)
        #expect(receipt.transactionID == nil)
        #expect(try SyncMeta(row: row, table: .receipts).syncSeq == 9)
    }
}

private func sampleRow(for table: SyncTable) -> SyncRow {
    let other = UUID(uuidString: "93000000-0000-0000-0000-000000000001")!
    let sept = day(2026, 9, 1)
    switch table {
    case .categories:
        return CategoryRow(id: rowID, key: "groceries", name: "Groceries", icon: "cart.fill", color: nil, kind: "expense", sortOrder: 0, archived: false).encoded(userID: user)
    case .merchantRules:
        return MerchantRuleRow(id: rowID, merchantKey: "esselunga", categoryKey: "groceries", scope: "personal", hits: 2).encoded(userID: user)
    case .settings:
        return SettingsRows(targetMonths: 16, startDate: sept, payoffStrategy: "highestInterest", homeCurrency: "EUR")
            .encoded(userID: user, calendar: rome)["targetMonths"]!
    case .income:
        return IncomeRow(id: rowID, name: "Salary", amount: 1750, kind: "variable", payday: 28, isActive: true).encoded(userID: user)
    case .incomeActuals:
        return IncomeActualRow(id: rowID, incomeID: other, month: sept, amount: Decimal(string: "1520.40")!).encoded(userID: user, calendar: rome)
    case .expenses:
        return ExpenseRow(id: rowID, name: "Rent", amount: 900, category: "Fixed", dueDay: nil, isActive: true).encoded(userID: user)
    case .debts:
        return DebtRow(id: rowID, localID: 4, name: "UniCredit", balance: Decimal(string: "6663.60")!, apr: Decimal(string: "8.75")!,
                       minimumPayment: Decimal(string: "315.75")!, extraPayment: 20, dueDay: nil, priority: 4).encoded(userID: user)
    case .debtPayments:
        return DebtPaymentRow(id: rowID, debtID: other, amount: 300, interestPortion: Decimal(string: "12.10")!, appliedAmount: 300,
                              date: day(2026, 9, 3), isPaid: true, isEarlyPayoff: false, previousMinimum: nil,
                              newMinimum: Decimal(string: "250.5")!, note: "Sept").encoded(userID: user, calendar: rome)
    case .transactions:
        return TransactionRow(id: rowID, occurredAt: day(2026, 9, 3, hour: 18), merchant: "Esselunga", amount: Decimal(string: "12.5")!,
                              isCredit: false, categoryKey: "groceries", account: "Cash", notes: "", currency: "EUR", taxAmount: nil,
                              scope: "personal", source: "manual", receiptID: nil).encoded(userID: user, calendar: rome)
    case .losses:
        return LossRow(id: rowID, date: day(2026, 9, 4), amount: 20, reason: "fine", note: "Parking").encoded(userID: user, calendar: rome)
    case .snapshots:
        return SnapshotRow(id: rowID, month: sept, income: 1750, expenses: 100, debtMinimums: Decimal(string: "1220.75")!,
                           debtBalance: Decimal(string: "14649.32")!).encoded(userID: user, calendar: rome)
    case .budgets:
        return BudgetRow(id: rowID, categoryKey: "groceries", monthlyLimit: 400).encoded(userID: user)
    case .receipts:
        return [:]
    }
}

@Suite("Sync ledger")
struct SyncLedgerTests {
    @Test("A row is dirty until it is recorded as pushed, and again once edited")
    func dirtiness() {
        var ledger = SyncLedger(userID: "u")
        #expect(ledger.isDirty(table: "t", id: "1", fingerprint: "a"))
        ledger.record(table: "t", id: "1", fingerprint: "a")
        #expect(!ledger.isDirty(table: "t", id: "1", fingerprint: "a"))
        #expect(ledger.isDirty(table: "t", id: "1", fingerprint: "b"))
    }

    @Test("Known rows missing locally are deletions to push")
    func deletions() {
        var ledger = SyncLedger()
        ledger.record(table: "t", id: "1", fingerprint: "a")
        ledger.record(table: "t", id: "2", fingerprint: "b")
        ledger.record(table: "other", id: "9", fingerprint: "c")
        #expect(ledger.deletedLocally(table: "t", localIDs: ["1", "3"]) == ["2"])
        ledger.forget(table: "t", id: "2")
        #expect(ledger.deletedLocally(table: "t", localIDs: ["1"]).isEmpty)
        #expect(ledger.deletedLocally(table: "empty", localIDs: []).isEmpty)
    }

    @Test("Cursors only move forward")
    func cursors() {
        var ledger = SyncLedger()
        #expect(ledger.cursor(for: "t") == 0)
        ledger.advanceCursor(for: "t", to: 40)
        ledger.advanceCursor(for: "t", to: 12)
        #expect(ledger.cursor(for: "t") == 40)
    }

    @Test("The ledger survives being stored")
    func codable() throws {
        var ledger = SyncLedger(userID: "u")
        ledger.advanceCursor(for: "t", to: 5)
        ledger.record(table: "t", id: "1", fingerprint: "a")
        ledger.seededCategories = true
        let data = try JSONEncoder().encode(ledger)
        #expect(try JSONDecoder().decode(SyncLedger.self, from: data) == ledger)
    }

    @Test("Merge decisions follow last-write-wins in server order")
    func merge() {
        #expect(SyncMerge.decide(localExists: false, localDirty: false, remoteDeleted: false) == .insert)
        #expect(SyncMerge.decide(localExists: false, localDirty: false, remoteDeleted: true) == .skip)
        #expect(SyncMerge.decide(localExists: true, localDirty: false, remoteDeleted: false) == .update)
        #expect(SyncMerge.decide(localExists: true, localDirty: true, remoteDeleted: false) == .keepLocal)
        #expect(SyncMerge.decide(localExists: true, localDirty: false, remoteDeleted: true) == .deleteLocal)
        #expect(SyncMerge.decide(localExists: true, localDirty: true, remoteDeleted: true) == .keepLocal)
        #expect(!SyncMerge.isLastPage(rowCount: 500, pageSize: 500))
        #expect(SyncMerge.isLastPage(rowCount: 499, pageSize: 500))
    }

    @Test("Rows migrated with a shared default id are found, first holder kept")
    func duplicateIDs() {
        let shared = UUID()
        let unique = UUID()
        #expect(SyncIdentity.duplicatePositions(in: [shared, unique, shared, shared]) == [2, 3])
        #expect(SyncIdentity.duplicatePositions(in: [unique]).isEmpty)
    }

    @Test("A new debt number is one past the highest in use")
    func debtNumbers() {
        #expect(DebtNumbering.nextFree(after: [1, 4, 2]) == 5)
        #expect(DebtNumbering.nextFree(after: []) == 1)
    }
}

@Suite("Category keys")
struct CategoryKeyTests {
    @Test("The seed list is the contract's eighteen keys, all valid")
    func seedList() {
        #expect(CategoryKeys.defaults.count == 18)
        #expect(CategoryKeys.defaults.first?.key == "groceries")
        #expect(CategoryKeys.defaults.last?.key == "other")
        #expect(CategoryKeys.defaults.allSatisfy { CategoryKeys.isValidKey($0.key) })
        #expect(Set(CategoryKeys.defaults.map(\.sortOrder)).count == 18)
    }

    @Test("Presets map to the contract's keys")
    func presets() {
        #expect(CategoryKeys.key(forLocal: "General") == "other")
        #expect(CategoryKeys.key(forLocal: "Tools") == "office_supplies")
        #expect(CategoryKeys.key(forLocal: "Food") == "groceries")
        #expect(CategoryKeys.key(forLocal: "Transport") == "transport")
        #expect(CategoryKeys.key(forLocal: "Bills") == "utilities")
        #expect(CategoryKeys.key(forLocal: "Shopping") == "shopping")
        #expect(CategoryKeys.key(forLocal: "Health") == "health")
        #expect(CategoryKeys.presetKeys.values.allSatisfy { CategoryKeys.defaultKeys.contains($0) })
    }

    @Test("Legacy names map the way the web maps them, whatever their case")
    func legacyNames() {
        #expect(CategoryKeys.key(forLocal: "Uncategorized") == "other")
        #expect(CategoryKeys.key(forLocal: "food") == "groceries")
        #expect(CategoryKeys.key(forLocal: "BILLS") == "utilities")
        #expect(CategoryKeys.key(forLocal: "") == "other")
        #expect(CategoryKeys.key(forLocal: " Food ") == "groceries")
        #expect(CategoryKeys.legacyKeys.values.allSatisfy { CategoryKeys.defaultKeys.contains($0) })
    }

    @Test("A key pulled from the server pushes back unchanged", arguments: CategoryKeys.defaults.map(\.key) + ["gym", "cafe_bar"])
    func roundTrip(key: String) {
        #expect(CategoryKeys.key(forLocal: key) == key)
    }

    @Test("Free-text categories become slugs rather than disappearing into other")
    func slugs() {
        #expect(CategoryKeys.key(forLocal: "Gym") == "gym")
        #expect(CategoryKeys.key(forLocal: "Café & Bar") == "cafe_bar")
        #expect(CategoryKeys.key(forLocal: "  Kids' stuff! ") == "kids_stuff")
        #expect(CategoryKeys.key(forLocal: "مطاعم") == "other")
        #expect(CategoryKeys.slug(String(repeating: "a", count: 60)).count == 40)
        #expect(CategoryKeys.key(forLocal: "eating_out") == "eating_out")
    }

}

@Suite("Backend configuration")
struct BackendConfigurationTests {
    @Test("A project URL and key are accepted")
    func valid() throws {
        let config = try BackendConfiguration.parse(url: " https://abc.supabase.co ", anonKey: "eyJ.key")
        #expect(config.url.absoluteString == "https://abc.supabase.co")
        #expect(config.anonKey == "eyJ.key")
        #expect(try BackendConfiguration.parse(url: "http://127.0.0.1:54321", anonKey: "k").url.port == 54321)
    }

    @Test("Unset or unexpanded build settings are reported as missing")
    func missing() {
        #expect(throws: BackendConfiguration.Problem.missing("SupabaseURL")) {
            try BackendConfiguration.parse(url: "$(SUPABASE_URL)", anonKey: "k")
        }
        #expect(throws: BackendConfiguration.Problem.missing("SupabaseAnonKey")) {
            try BackendConfiguration.parse(url: "https://abc.supabase.co", anonKey: "")
        }
        #expect(throws: BackendConfiguration.Problem.missing("SupabaseURL")) {
            try BackendConfiguration.parse(url: nil, anonKey: "k")
        }
    }

    @Test("A URL cut short by an xcconfig comment, or plain http to a server, is refused")
    func invalid() {
        #expect(throws: BackendConfiguration.Problem.invalidURL("https:")) {
            try BackendConfiguration.parse(url: "https:", anonKey: "k")
        }
        #expect(throws: BackendConfiguration.Problem.invalidURL("http://abc.supabase.co")) {
            try BackendConfiguration.parse(url: "http://abc.supabase.co", anonKey: "k")
        }
    }
}
