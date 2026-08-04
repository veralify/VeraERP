import SwiftUI

// MARK: - CountdownView

/// Live countdown timer that updates every second using TimelineView.
struct CountdownView: View {
    let revealAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, revealAt.timeIntervalSince(context.date))
            countdownStack(remaining: remaining)
        }
    }

    // MARK: - Layout

    private func countdownStack(remaining: TimeInterval) -> some View {
        let days    = Int(remaining) / 86400
        let hours   = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        return HStack(spacing: 12) {
            unitView(value: days, label: "DAYS")
            separatorView
            unitView(value: hours, label: "HRS")
            separatorView
            unitView(value: minutes, label: "MIN")
            separatorView
            unitView(value: seconds, label: "SEC")
        }
    }

    private func unitView(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: value)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
    }

    private var separatorView: some View {
        Text(":")
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 14)
    }
}
