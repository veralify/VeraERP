import SwiftUI

/// The app's one date control: a tappable value that opens the themed calendar.
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
        /// A compact chip, for a row of chips.
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
                HStack(spacing: Theme.Spacing.sm) {
                    Text(label)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: Theme.Spacing.sm)
                    HStack(spacing: 6) {
                        Text(valueText)
                            .font(Theme.Typography.subheadlineStrong)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "calendar")
                            .font(Theme.Typography.captionStrong)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(minHeight: 36)
                    .background(Theme.surfaceMuted, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                }
                .frame(minHeight: Theme.Icon.minTapTarget)
                .contentShape(.rect)

            case .chip:
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .imageScale(.small)
                        .foregroundStyle(Theme.accent)
                    Text(chipText)
                        .font(Theme.Typography.subheadlineStrong)
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: Theme.Border.hairline)
                }
                .padding(.vertical, 4)
                .contentShape(.rect)
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
                Theme.canvas.ignoresSafeArea()

                Group {
                    if let range {
                        DatePicker("Date", selection: $date, in: range, displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.graphical)
                // Set here rather than inherited: a sheet is its own
                // presentation, and the accent is what makes the selected day
                // and the month arrows read as ours.
                .tint(Theme.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.bodyStrong)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.canvas)
        .presentationCornerRadius(Theme.Radius.sheet)
    }
}
