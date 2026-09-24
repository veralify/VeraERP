import SwiftUI
import SwiftData
import VeralifyCore

/// Navigation value for one category's entries.
struct CategoryRoute: Hashable {
    let category: String
    /// Money in or money out, so the list matches the chart it came from.
    let direction: EntryDirection
    /// `yyyy-MM-dd` bounds, or nil for everything. `Timeframe` is not `Hashable`
    /// as a route because a custom one carries `Date`s that would not survive a
    /// round trip cleanly; two plain days do.
    let from: Date?
    let to: Date?
}

/// Every entry behind one slice of the ring.
///
/// The chevron on a category row had nowhere to go. A share and a percentage
/// say how much; this says what it was actually made of.
struct CategoryDetailView: View {
    let route: CategoryRoute

    @Query(sort: \TransactionRecord.occurredAt, order: .reverse) private var all: [TransactionRecord]

    private var entries: [TransactionRecord] {
        all.filter { record in
            guard record.category == route.category, record.direction == route.direction else {
                return false
            }
            if let from = route.from, record.occurredAt < from { return false }
            if let to = route.to, record.occurredAt >= to { return false }
            return true
        }
    }

    private var total: Decimal { entries.reduce(Decimal(0)) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    if entries.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "Nothing here",
                            message: "No entries in this category for the period you picked."
                        )
                    } else {
                        // The ledger's rhythm: rows 10pt apart, the list as a
                        // whole further from the summary above it. At one
                        // spacing for everything, the header read as the
                        // first entry.
                        VStack(spacing: 10) {
                            ForEach(entries) { TransactionRow(record: $0) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(LocalizedStringKey(route.category))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 14) {
            CategoryStyle.badge(route.category, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyFormat.string(total))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}
