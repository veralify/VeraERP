import SwiftUI
import VeralifyCore

extension Timeframe {
    var title: LocalizedStringKey {
        switch self {
        case .day:    "Day"
        case .week:   "Week"
        case .month:  "Month"
        case .year:   "Year"
        case .all:    "All"
        case .custom: "Custom"
        }
    }

    /// What the button says — the period itself, not its name, once one is
    /// chosen. "September" tells you more than "Month".
    func caption(now: Date = .now, calendar: Calendar = .current) -> String {
        switch self {
        case .day:
            return now.formatted(.dateTime.day().month(.wide))
        case .week:
            guard let interval = interval(containing: now, calendar: calendar) else { return "" }
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            return now.formatted(.dateTime.month(.wide).year())
        case .year:
            return now.formatted(.dateTime.year())
        case .all:
            return String(localized: "Everything recorded")
        case .custom(let start, let end):
            let low = min(start, end)
            let high = max(start, end)
            return "\(low.formatted(.dateTime.day().month(.abbreviated))) – \(high.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }
}

/// The control that opens the timeframe sheet.
struct TimeframeButton: View {
    @Binding var timeframe: Timeframe
    @State private var isPicking = false

    var body: some View {
        Button { isPicking = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.lime)

                VStack(alignment: .leading, spacing: 1) {
                    Text(timeframe.title)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(timeframe.caption())
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $isPicking) {
            TimeframeSheet(timeframe: $timeframe)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
    }
}

/// Day, week, month, year, everything — or a range of your own.
struct TimeframeSheet: View {
    @Binding var timeframe: Timeframe
    @Environment(\.dismiss) private var dismiss

    @State private var start = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var end = Date()
    @State private var isPickingRange = false

    /// Two rows of three, as in a keypad: six options in a grid are read at a
    /// glance where a list of six has to be scanned.
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // The sheet is a fixed 340pt. The grid alone fits, but with the
            // custom range open (two dates and a button) it runs to about 350,
            // and further at large text, which cut off "Use this range". It
            // scrolls only when it has to.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Time frame")
                        .font(.caption.weight(.bold))
                        .kerning(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textTertiary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Timeframe.presets, id: \.self) { option in
                            chip(option, isSelected: timeframe == option) {
                                timeframe = option
                                dismiss()
                            }
                        }

                        chip(.custom(start: start, end: end), isSelected: timeframe.isCustom) {
                            withAnimation(.snappy(duration: 0.25)) { isPickingRange = true }
                        }
                    }

                    if isPickingRange || timeframe.isCustom {
                        VStack(spacing: 10) {
                            DateField(label: "From", date: $start)
                            DateField(label: "To", date: $end)
                            PrimaryButton(title: "Use this range", enabled: true) {
                                timeframe = .custom(start: start, end: end)
                                dismiss()
                            }
                        }
                        .padding(14)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.card))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func chip(
        _ option: Timeframe,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Theme.lime : Theme.surface, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.pressable)
    }
}
