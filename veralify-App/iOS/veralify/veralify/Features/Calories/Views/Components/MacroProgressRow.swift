import SwiftUI

/// A single macro's progress (e.g. "Protein 75/150g") shown as a small ring
/// with a colored icon, matching Cal AI's three-macro summary row.
struct MacroProgressRow: View {
    let title: String
    let systemImage: String
    let color: Color
    let eaten: Double
    let goal: Double

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(eaten / goal, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(AppTheme.surface, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 48, height: 48)

            Text("\(Int(eaten))/\(Int(goal))g")
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(eaten)) of \(Int(goal)) grams")
    }
}

#Preview {
    HStack {
        MacroProgressRow(title: "Protein", systemImage: "flame.fill", color: .red, eaten: 75, goal: 150)
        MacroProgressRow(title: "Carbs", systemImage: "leaf.fill", color: .orange, eaten: 138, goal: 275)
        MacroProgressRow(title: "Fat", systemImage: "drop.fill", color: .blue, eaten: 35, goal: 70)
    }
    .padding()
}
