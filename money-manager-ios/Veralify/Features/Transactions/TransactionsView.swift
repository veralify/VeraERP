import SwiftUI
import SwiftData

/// The ledger: what actually happened, as opposed to the plan on the dashboard.
struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var all: [TransactionRecord]

    @State private var scope: EntryScope = .business
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var adding: EntryDirection?
    @State private var editing: TransactionRecord?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var entries: [TransactionRecord] {
        all.filter { $0.scope == scope }
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    scopeBar
                    WeekStrip(selected: $selectedDay)
                    balanceCard

                    if entries.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet.rectangle",
                            title: "No entries yet",
                            message: "Add your first credit or debit to start the ledger."
                        )
                        .padding(.top, 20)
                    } else {
                        Text("Showing \(entries.count) entries")  // pluralised in the catalog
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)

                        ForEach(days, id: \.day) { group in
                            daySection(group)
                                .id(group.day)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 108)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedDay) { _, day in
                // Jump to the chosen day if it has entries; otherwise leave the
                // list where it is rather than scrolling somewhere arbitrary.
                guard days.contains(where: { $0.day == day }) else { return }
                // A long scroll is exactly the kind of motion Reduce Motion is
                // meant to suppress, so it jumps instead.
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                    proxy.scrollTo(day, anchor: .top)
                }
            }
        }
        .sheet(item: $adding) { direction in
            QuickAddSheet(scope: scope, initialDirection: direction)
                .presentationBackground(Theme.background)
        }
        .sheet(item: $editing) { record in
            TransactionEditSheet(record: record)
                .presentationBackground(Theme.background)
        }
        .onAppear { QuickAddRouter.shared.scope = scope }
        .onChange(of: scope) { _, value in QuickAddRouter.shared.scope = value }
    }

    private var scopeBar: some View {
        HStack(spacing: 4) {
            ForEach(EntryScope.allCases) { option in
                Button { scope = option } label: {
                    Label(option.title, systemImage: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scope == option ? Theme.textPrimary : Theme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(scope == option ? Theme.surfaceElevated : .clear, in: .capsule)
                }
                .buttonStyle(.pressableRow)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .background(Theme.surface, in: .capsule)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(group.day.formatted(.dateTime.month(.wide).day().year()))
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

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

/// Lets the floating dock open the quick-add sheet with the scope the user is
/// currently looking at, without threading state through every screen.
@Observable
final class QuickAddRouter {
    @MainActor static let shared = QuickAddRouter()
    var scope: EntryScope = .business
    /// Set when an entry is committed; `MainTabView` shows the confirmation
    /// full-screen, which the sheet itself cannot do.
    var pendingFlash: EntryDirection?
}

struct TransactionRow: View {
    let record: TransactionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hexagon")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceElevated, in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(record.direction == .credit
                         ? "In from \(record.account)"
                         : "Out from \(record.account)")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(record.direction.sign)\(CurrencyFormat.string(record.amount))")
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(record.direction.accent)
            }

            HStack {
                Text(record.category)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                Spacer(minLength: 8)
                Text(record.occurredAt.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
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

