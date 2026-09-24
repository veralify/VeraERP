import Foundation
import SwiftData
import VeralifyCore

// Model ↔ row mapping for each synced table (contracts §2, "iOS model ↔ table").
//
// Encoding builds the value types in VeralifyCore from a record; `apply` goes
// the other way. `apply` only assigns a field whose wire form differs, so a
// pulled copy of a row this phone just pushed changes nothing — a free-text
// timestamp keeps its sub-millisecond precision, and a category an older
// build stored under a legacy name is not churned.

extension IncomeRow {
    init(_ model: IncomeSource) {
        self.init(
            id: model.id, name: model.name, amount: model.amount, kind: model.kind,
            payday: model.payday, isActive: model.isActive
        )
    }
}

extension IncomeSource {
    func apply(_ row: IncomeRow) {
        if name != row.name { name = row.name }
        if amount != row.amount { amount = row.amount }
        if IncomeRow(self).kind != row.kind { kind = row.kind }
        if payday != row.payday { payday = row.payday }
        if isActive != row.isActive { isActive = row.isActive }
    }
}

extension IncomeActual {
    /// Nil while the income it belongs to is unknown; such a row waits.
    var syncRow: IncomeActualRow? {
        guard let source else { return nil }
        return IncomeActualRow(id: id, incomeID: source.id, month: month, amount: amount)
    }

    func apply(_ row: IncomeActualRow, source newSource: IncomeSource, calendar: Calendar) {
        if source?.id != newSource.id { source = newSource }
        if SyncFormat.monthDate(month, calendar: calendar) != SyncFormat.monthDate(row.month, calendar: calendar) {
            month = row.month
        }
        if amount != row.amount { amount = row.amount }
    }
}

extension ExpenseRow {
    init(_ model: ExpenseItem) {
        self.init(
            id: model.id, name: model.name, amount: model.amount, category: model.category,
            dueDay: model.dueDay, isActive: model.isActive
        )
    }
}

extension ExpenseItem {
    func apply(_ row: ExpenseRow) {
        if name != row.name { name = row.name }
        if amount != row.amount { amount = row.amount }
        if category != row.category { category = row.category }
        if dueDay != row.dueDay { dueDay = row.dueDay }
        if isActive != row.isActive { isActive = row.isActive }
    }
}

extension DebtRow {
    init(_ model: DebtRecord) {
        self.init(
            id: model.id, localID: model.remoteID, name: model.name, balance: model.balance, apr: model.apr,
            minimumPayment: model.minimumPayment, extraPayment: model.extraPayment,
            dueDay: model.dueDay, priority: model.priority
        )
    }
}

extension DebtRecord {
    /// Everything except the number, which `SyncEngine` settles first because
    /// payments hang off it.
    func apply(_ row: DebtRow) {
        if name != row.name { name = row.name }
        if balance != row.balance { balance = row.balance }
        if apr != row.apr { apr = row.apr }
        if minimumPayment != row.minimumPayment { minimumPayment = row.minimumPayment }
        if extraPayment != row.extraPayment { extraPayment = row.extraPayment }
        if dueDay != row.dueDay { dueDay = row.dueDay }
        if priority != row.priority { priority = row.priority }
    }
}

extension DebtPayment {
    /// Nil while no debt carries this payment's number; such a row waits.
    func syncRow(debtIDs: [Int: UUID]) -> DebtPaymentRow? {
        guard let debtID = debtIDs[debtRemoteID] else { return nil }
        return DebtPaymentRow(
            id: id, debtID: debtID, amount: amount, interestPortion: interestPortion,
            appliedAmount: appliedAmount, date: date, isPaid: isPaid, isEarlyPayoff: isEarlyPayoff,
            previousMinimum: previousMinimum, newMinimum: newMinimum, note: note
        )
    }

    /// Stores the payment as recorded elsewhere. The debt's balance is *not*
    /// touched: it syncs as its own column, and applying the payment to it a
    /// second time here would take the money off twice.
    func apply(_ row: DebtPaymentRow, debtNumber: Int, calendar: Calendar) {
        if debtRemoteID != debtNumber { debtRemoteID = debtNumber }
        if amount != row.amount { amount = row.amount }
        if interestPortion != row.interestPortion { interestPortion = row.interestPortion }
        if appliedAmount != row.appliedAmount { appliedAmount = row.appliedAmount }
        if SyncFormat.calendarDate(date, calendar: calendar) != SyncFormat.calendarDate(row.date, calendar: calendar) {
            date = row.date
        }
        if isPaid != row.isPaid { isPaid = row.isPaid }
        if isEarlyPayoff != row.isEarlyPayoff { isEarlyPayoff = row.isEarlyPayoff }
        if previousMinimum != row.previousMinimum { previousMinimum = row.previousMinimum }
        if newMinimum != row.newMinimum { newMinimum = row.newMinimum }
        if note != row.note { note = row.note }
    }
}

extension TransactionRow {
    init(_ model: TransactionRecord) {
        self.init(
            id: model.id, occurredAt: model.occurredAt, merchant: model.name, amount: model.amount,
            isCredit: model.direction == .credit, categoryKey: CategoryKeys.key(forLocal: model.category),
            account: model.account, notes: model.notes, currency: model.currency, taxAmount: model.taxAmount,
            scope: model.scope.rawValue, source: model.sourceRaw, receiptID: model.receiptID
        )
    }
}

extension TransactionRecord {
    func apply(_ row: TransactionRow) {
        if SyncFormat.instant(occurredAt) != SyncFormat.instant(row.occurredAt) { occurredAt = row.occurredAt }
        if name != row.merchant { name = row.merchant }
        if amount != row.amount { amount = row.amount }
        let direction: EntryDirection = row.isCredit ? .credit : .debit
        if self.direction != direction { self.direction = direction }
        if CategoryKeys.key(forLocal: category) != row.categoryKey { category = row.categoryKey }
        if account != row.account { account = row.account }
        if notes != row.notes { notes = row.notes }
        if currency != row.currency { currency = row.currency }
        if taxAmount != row.taxAmount { taxAmount = row.taxAmount }
        let scope = EntryScope(rawValue: row.scope) ?? .personal
        if self.scope != scope { self.scope = scope }
        if sourceRaw != row.source { sourceRaw = row.source }
        if receiptID != row.receiptID { receiptID = row.receiptID }
    }
}

extension LossRow {
    init(_ model: MoneyLoss) {
        self.init(id: model.id, date: model.date, amount: model.amount, reason: model.reasonRaw, note: model.note)
    }
}

extension MoneyLoss {
    func apply(_ row: LossRow, calendar: Calendar) {
        if SyncFormat.calendarDate(date, calendar: calendar) != SyncFormat.calendarDate(row.date, calendar: calendar) {
            date = row.date
        }
        if amount != row.amount { amount = row.amount }
        if reasonRaw != row.reason { reasonRaw = row.reason }
        if note != row.note { note = row.note }
    }
}

extension SnapshotRow {
    init(_ model: MonthlySnapshot) {
        self.init(
            id: model.id, month: model.month, income: model.income, expenses: model.expenses,
            debtMinimums: model.debtMinimums, debtBalance: model.debtBalance
        )
    }
}

extension MonthlySnapshot {
    func apply(_ row: SnapshotRow, calendar: Calendar) {
        if SyncFormat.monthDate(month, calendar: calendar) != SyncFormat.monthDate(row.month, calendar: calendar) {
            month = row.month
        }
        if income != row.income { income = row.income }
        if expenses != row.expenses { expenses = row.expenses }
        if debtMinimums != row.debtMinimums { debtMinimums = row.debtMinimums }
        if debtBalance != row.debtBalance { debtBalance = row.debtBalance }
    }
}

extension BudgetRow {
    init(_ model: CategoryBudget) {
        self.init(id: model.id, categoryKey: CategoryKeys.key(forLocal: model.category), monthlyLimit: model.limit)
    }
}

extension CategoryBudget {
    func apply(_ row: BudgetRow) {
        if CategoryKeys.key(forLocal: category) != row.categoryKey { category = row.categoryKey }
        if limit != row.monthlyLimit { limit = row.monthlyLimit }
    }
}

extension CategoryRow {
    init(_ model: MoneyCategory) {
        self.init(
            id: model.id, key: model.key, name: model.name, icon: model.icon, color: model.color,
            kind: model.kind, sortOrder: model.sortOrder, archived: model.archived
        )
    }
}

extension MoneyCategory {
    func apply(_ row: CategoryRow) {
        if key != row.key { key = row.key }
        if name != row.name { name = row.name }
        if icon != row.icon { icon = row.icon }
        if color != row.color { color = row.color }
        if kind != row.kind { kind = row.kind }
        if sortOrder != row.sortOrder { sortOrder = row.sortOrder }
        if archived != row.archived { archived = row.archived }
    }
}

extension MerchantRuleRow {
    init(_ model: MerchantRule) {
        self.init(
            id: model.id, merchantKey: model.merchantKey, categoryKey: model.categoryKey,
            scope: model.scope, hits: model.hits
        )
    }
}

extension MerchantRule {
    func apply(_ row: MerchantRuleRow) {
        if merchantKey != row.merchantKey { merchantKey = row.merchantKey }
        if categoryKey != row.categoryKey { categoryKey = row.categoryKey }
        if scope != row.scope { scope = row.scope }
        if hits != row.hits { hits = row.hits }
    }
}

extension SettingsRows {
    init(_ model: PlanSettings) {
        self.init(
            targetMonths: model.targetMonths, startDate: model.startDate,
            payoffStrategy: model.payoffStrategyRaw, homeCurrency: AppSettings.currencyCode
        )
    }
}

extension PlanSettings {
    func apply(_ rows: SettingsRows, calendar: Calendar) {
        if targetMonths != rows.targetMonths { targetMonths = rows.targetMonths }
        if SyncFormat.calendarDate(startDate, calendar: calendar) != SyncFormat.calendarDate(rows.startDate, calendar: calendar) {
            startDate = rows.startDate
        }
        if payoffStrategyRaw != rows.payoffStrategy { payoffStrategyRaw = rows.payoffStrategy }
        // The home currency is the display currency, which lives in
        // UserDefaults rather than the store (see `AppSettings`).
        if AppSettings.currencyCode != rows.homeCurrency {
            UserDefaults.standard.set(rows.homeCurrency, forKey: AppSettings.Key.currencyCode)
        }
    }
}
