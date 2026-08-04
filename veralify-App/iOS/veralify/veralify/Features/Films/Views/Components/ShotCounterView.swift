import SwiftUI

// MARK: - ShotCounterView

/// Pill showing shots remaining on the camera screen.
struct ShotCounterView: View {
    let remaining: Int
    let limit: Int

    private var fraction: Double { Double(remaining) / Double(max(1, limit)) }
    private var isLow: Bool { remaining <= max(1, limit / 10) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.caption.weight(.semibold))

            Text("\(remaining)")
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.2), value: remaining)

            Text("/ \(limit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(isLow ? Color.red : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(isLow ? Color.red.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1))
    }
}
