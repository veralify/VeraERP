import SwiftUI

// MARK: - RevealView

/// Full-screen animated reveal experience. Shots unlock one-by-one
/// with a staggered animation, then transition to the full grid.
struct RevealView: View {
    let shots: [FilmShot]
    let filmName: String
    @Environment(\.dismiss) private var dismiss

    @State private var revealedCount = 0
    @State private var showGrid = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showGrid {
                revealGrid
                    .transition(.opacity)
            } else {
                revealAnimation
            }
        }
        .task { await runRevealSequence() }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding(.top, 60)
            .padding(.leading, 20)
            .opacity(showGrid ? 1 : 0)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Animation Phase

    private var revealAnimation: some View {
        VStack(spacing: 28) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)
                .symbolEffect(.variableColor.iterative)

            Text(filmName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Revealing \(revealedCount) of \(shots.count) shots…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .contentTransition(.numericText())
                .animation(.easeInOut, value: revealedCount)

            ProgressView(value: Double(revealedCount), total: Double(max(1, shots.count)))
                .tint(AppTheme.accent)
                .frame(width: 200)
        }
    }

    // MARK: - Grid Phase

    private var revealGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(filmName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 70)
                    .padding(.bottom, 16)

                Text("\(shots.count) moments")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 20)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                        AsyncImage(url: URL(string: shot.storagePath)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            default:
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .animation(.spring(duration: 0.4).delay(Double(index) * 0.03), value: showGrid)
                    }
                }
            }
        }
    }

    // MARK: - Reveal Sequence

    private func runRevealSequence() async {
        for i in 0..<shots.count {
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation { revealedCount = i + 1 }
        }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.easeInOut(duration: 0.5)) { showGrid = true }
    }
}
