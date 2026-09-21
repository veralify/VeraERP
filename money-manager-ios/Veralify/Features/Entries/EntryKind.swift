import SwiftUI

/// The three things a user can record. Drives the form, the list screens and
/// the colour each one is shown in.
enum EntryKind: String, CaseIterable, Identifiable, Hashable {
    case income, expense, debt

    var id: String { rawValue }

    var shortTitle: LocalizedStringKey {
        switch self {
        case .income:  "Income"
        case .expense: "Expense"
        case .debt:    "Debt"
        }
    }

    var listTitle: LocalizedStringKey {
        switch self {
        case .income:  "Income sources"
        case .expense: "Fixed expenses"
        case .debt:    "Debts"
        }
    }

    var amountLabel: LocalizedStringKey {
        switch self {
        case .debt: "Remaining balance"
        default:    "Monthly amount"
        }
    }

    var accent: Color {
        switch self {
        case .income:  Theme.lime
        case .expense: Theme.yellow
        case .debt:    Theme.red
        }
    }

    var emptyMessage: LocalizedStringKey {
        switch self {
        case .income:  "Add your salary or any other monthly income."
        case .expense: "Add rent, bills and any recurring monthly commitment."
        case .debt:    "Add your debts and we'll build your payoff plan."
        }
    }

    var emptyIcon: String {
        switch self {
        case .income:  "arrow.down.circle"
        case .expense: "arrow.up.circle"
        case .debt:    "creditcard"
        }
    }
}

/// A record being edited. Carries the model object itself, since SwiftData
/// models are reference types and edits write straight through.
enum EditTarget: Identifiable {
    case income(IncomeSource)
    case expense(ExpenseItem)
    case debt(DebtRecord)

    var id: String {
        switch self {
        case .income(let item):  "income-\(item.persistentModelID.hashValue)"
        case .expense(let item): "expense-\(item.persistentModelID.hashValue)"
        case .debt(let item):    "debt-\(item.remoteID)"
        }
    }

    var kind: EntryKind {
        switch self {
        case .income:  .income
        case .expense: .expense
        case .debt:    .debt
        }
    }
}
