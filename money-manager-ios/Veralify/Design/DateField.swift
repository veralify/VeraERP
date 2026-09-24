import SwiftUI

/// The app's one date control: a tappable value that opens a dark calendar.
///
/// Screens used to roll their own. Most used a compact `DatePicker`, whose
/// popover arrives in the system's own colours and ignores the palette
/// entirely; only the quick-add sheet opened the themed graphical calendar. This
/// is that calendar, available everywhere.
struct DateField: View {
    let label: LocalizedStringKey
    @Binding var date: Date
    var style: Style = .row
    /// Dates outside this are not selectable. Open-ended by default.
    var range: ClosedRange<Date>?

    @State private var isPicking = false

    enum Style {
        /// A labelled row, for a form.
        case row
        /// A capsule, for a row of chips.
        case chip
    }

    private var valueText: String {
        Calendar.current.isDateInToday(date)
            ? String(localized: "Today")
            : date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private var chipText: String {
        Calendar.current.isDateInToday(date)
            ? String(localized: "Today")
            : date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        Button { isPicking = true } label: {
            switch style {
            case .row:
                HStack {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    HStack(spacing: 7) {
                        Text(valueText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.lime)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surfaceElevated, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                    // The date is the value; when the row runs short the
                    // label beside it wraps instead.
                    .layoutPriority(1)
                }
                .contentShape(.rect)

            case .chip:
                HStack(spacing: 7) {
                    Image(systemName: "calendar").font(.system(size: 13, weight: .medium))
                    Text(chipText).font(.subheadline.weight(.medium)).lineLimit(1)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Theme.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $isPicking) {
            CalendarSheet(date: $date, range: range)
        }
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
    }
}

/// The calendar itself, on the app's background and in its accent.
private struct CalendarSheet: View {
    @Binding var date: Date
    let range: ClosedRange<Date>?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Group {
                    if let range {
                        DatePicker("Date", selection: $date, in: range, displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.graphical)
                // Set here rather than inherited: a sheet is its own
                // presentation, and the lime is what makes the selected day and
                // the month arrows read as ours.
                .tint(Theme.lime)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.background)
    }
}
