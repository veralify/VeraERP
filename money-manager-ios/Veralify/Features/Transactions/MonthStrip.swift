import SwiftUI

/// Pick a month to look at.
///
/// Replaces a week strip that only scrolled the list to a day. Everything else
/// in the app is monthly — the plan, the budgets, the category ring — so the
/// ledger being an endless scroll of everything ever recorded made it the one
/// screen that could not be compared with any of them.
struct MonthStrip: View {
    /// First day of the selected month.
    @Binding var selected: Date
    /// How far back to offer. A year is plenty and keeps the strip scrollable
    /// rather than endless.
    var monthsBack: Int = 11

    private var calendar: Calendar { .current }

    private var months: [Date] {
        let start = calendar.startOfMonth(for: .now)
        return (0...monthsBack)
            .compactMap { calendar.date(byAdding: .month, value: -$0, to: start) }
            .reversed()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(months, id: \.self) { month in
                        Button { selected = month } label: {
                            Text(label(for: month))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected(month) ? Theme.onAccent : Theme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected(month) ? Theme.lime : Theme.surface,
                                    in: .capsule
                                )
                                .lineLimit(1)
                                // The pill is under 44pt tall; the tap area
                                // is stretched to 44 without growing the pill.
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .id(month)
                    }
                }
                // No inset of its own: the first and last pills line up with
                // the screen gutter and the cards below. Clipping is already
                // off, so a pressed pill is not cut at the edge.
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onAppear {
                // Opens on the current month, which is at the far end.
                proxy.scrollTo(months.last, anchor: .trailing)
            }
        }
    }

    private func isSelected(_ month: Date) -> Bool {
        calendar.isDate(month, equalTo: selected, toGranularity: .month)
    }

    private func label(for month: Date) -> String {
        if calendar.isDate(month, equalTo: .now, toGranularity: .month) {
            return String(localized: "This month")
        }
        // The year only when it is not this one — "March" beats "March 2026"
        // eleven times out of twelve.
        let sameYear = calendar.isDate(month, equalTo: .now, toGranularity: .year)
        return month.formatted(sameYear ? .dateTime.month(.wide) : .dateTime.month(.abbreviated).year())
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
