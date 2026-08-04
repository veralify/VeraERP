import SwiftUI

// MARK: - RevealBlurView

/// Blurred overlay rendered on top of a grid of not-yet-revealed shots.
/// Shows a lock icon and the reveal date.
struct RevealBlurView: View {
    let revealAt: Date
    var onRevealPassed: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.pulse)

                Text("Photos reveal on")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(revealAt, style: .date)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                CountdownView(revealAt: revealAt)
                    .padding(.top, 4)
            }
            .padding(32)
        }
        .onChange(of: Date()) { _, _ in
            if revealAt <= Date() { onRevealPassed?() }
        }
    }
}
