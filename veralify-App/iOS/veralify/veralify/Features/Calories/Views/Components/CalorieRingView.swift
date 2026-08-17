import SwiftUI

/// Circular calories-eaten-vs-goal progress ring, styled after Cal AI's
/// home screen ring.
struct CalorieRingView: View {
    let eaten: Int
    let goal: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.surface, lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.premiumGradient,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)

            VStack(spacing: 2) {
                Text("\(eaten)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text("of \(goal) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eaten) of \(goal) calories eaten")
    }
}

#Preview {
    CalorieRingView(eaten: 1250, goal: 2200, progress: 1250.0 / 2200.0)
}
