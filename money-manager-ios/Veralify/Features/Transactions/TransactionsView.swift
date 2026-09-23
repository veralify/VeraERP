import SwiftUI
import SwiftData

/// Navigation value for the full ledger.
struct LedgerRoute: Hashable {}

/// The ledger: what actually happened, as opposed to the plan on the dashboard.
///
/// Pushed from Today's list of the day's entries rather than owning a tab. A
/// complete history of everything ever typed is a reference you consult, not a
/// place you go every day — and Today already shows the part of it that is
/// still fresh.
struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var all: [TransactionRecord]

    @State private var month: Date = Calendar.current.startOfMonth(for: .now)
    @State private var adding: EntryDirection?
    @State private var editing: TransactionRecord?

    /// Every entry in the month, whatever scope it was recorded under.
    ///
    /// The Business/Personal bar is gone. It was an accounting dimension in a
    /// household app, sitting permanently across the top of the ledger and
    /// silently hiding half the entries from anyone who never noticed it. The
    /// field stays on the model so nothing recorded under it is lost, and it
    /// simply no longer decides what you can see.
    private var entries: [TransactionRecord] {
        all.filter { Calendar.current.isDate($0.occurredAt, equalTo: month, toGranularity: .month) }
    }

    /// Entries grouped by day, newest first — the shape the list renders.
    private var days: [(day: Date, items: [TransactionRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var credit: Decimal { entries.filter { $0.direction == .credit }.reduce(0) { $0 + $1.amount } }
    private var debit: Decimal { entries.filter { $0.direction == .debit }.reduce(0) { $0 + $1.amount } }
    private var net: Decimal { credit - debit }

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    MonthStrip(selected: $month)
                    balanceCard

                    if entries.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet.rectangle",
                            title: "Nothing this month",
                            message: "Pick another month, or tap Add to record something."
                        )
                        .padding(.top, 20)
                    } else {
                        Text("Showing \(entries.count) entries")  // pluralised in the catalog
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)

                        ForEach(days, id: \.day) { group in
                            daySection(group)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // A pushed screen sits above the floating bar, so it only needs
                // the ordinary bottom margin.
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        .sheet(item: $adding) { direction in
            QuickAddSheet(initialDirection: direction)
                .presentationBackground(Theme.background)
        }
        .sheet(item: $editing) { record in
            TransactionEditSheet(record: record)
                .presentationBackground(Theme.background)
        }
        .navigationTitle("Entries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NET BALANCE")
                        .font(.caption.weight(.bold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text(CurrencyFormat.string(net))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                balanceLine("Money in", credit, Theme.green)
                balanceLine("Money out", debit, Theme.red)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func balanceLine(_ label: LocalizedStringKey, _ amount: Decimal, _ accent: Color) -> some View {
        HStack(spacing: 10) {
            Capsule().fill(accent).frame(width: 3, height: 16)
            Text(label).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(CurrencyFormat.string(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func daySection(_ group: (day: Date, items: [TransactionRecord])) -> some View {
        let dayCredit = group.items.filter { $0.direction == .credit }.reduce(Decimal(0)) { $0 + $1.amount }
        let dayDebit = group.items.filter { $0.direction == .debit }.reduce(Decimal(0)) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 10) {
            // The day's own in and out beside its date: the question a ledger
            // gets asked most is "what did that day cost me", and it was only
            // answerable by adding the rows up by eye.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.day.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer(minLength: 8)

                if dayCredit > 0 {
                    Text("+\(CurrencyFormat.string(dayCredit))")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.green)
                }
                if dayDebit > 0 {
                    Text("−\(CurrencyFormat.string(dayDebit))")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.red)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            ForEach(group.items) { item in
                Button { editing = item } label: {
                    TransactionRow(record: item)
                }
                .buttonStyle(.pressableRow)
                .contextMenu {
                    Button(role: .destructive) {
                        context.delete(item)
                        try? context.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Carries the confirmation flash from the quick-add sheet up to the app level.
@Observable
final class QuickAddRouter {
    @MainActor static let shared = QuickAddRouter()
    /// Set when an entry is committed; `MainTabView` shows the confirmation
    /// full-screen, which the sheet itself cannot do.
    var pendingFlash: EntryDirection?
}

struct TransactionRow: View {
    let record: TransactionRecord

    var body: some View {
        HStack(spacing: 12) {
            CategoryStyle.badge(record.category, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                // The category leads and the note follows. A row titled with
                // whatever got typed into "who's it for?" read as a list of
                // strangers; the category is what the eye is scanning for.
                Text(LocalizedStringKey(record.category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.direction.sign)\(CurrencyFormat.string(record.amount))")
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(record.direction.accent)
                Text(record.occurredAt.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    /// What was typed, or where the money moved when nothing was.
    ///
    /// An entry saved without a name gets the category as its name, so without
    /// this the row printed "Bills" over "Bills".
    private var subtitle: String {
        guard !record.name.isEmpty, record.name != record.category else {
            return record.direction == .credit
                ? String(localized: "In from \(record.account)")
                : String(localized: "Out from \(record.account)")
        }
        return record.name
    }
}

/// Seven-day strip around the selected date.
struct WeekStrip: View {
    @Binding var selected: Date

    private var days: [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selected) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)
                let isToday = Calendar.current.isDateInToday(day)

                Button { selected = Calendar.current.startOfDay(for: day) } label: {
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background {
                                if isSelected {
                                    Circle().fill(Theme.red)
                                } else if isToday {
                                    Circle().strokeBorder(Theme.stroke, lineWidth: 1)
                                } else {
                                    Circle().strokeBorder(Theme.stroke.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressableRow)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            }
        }
    }
}

