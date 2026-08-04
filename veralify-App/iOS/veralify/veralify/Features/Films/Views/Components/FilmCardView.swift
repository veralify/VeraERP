import SwiftUI

// MARK: - FilmCardView

struct FilmCardView: View {
    let film: Film

    var body: some View {
        HStack(spacing: 14) {
            filmIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(film.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                statusLabel
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var filmIcon: some View {
        ZStack {
            Circle()
                .fill(film.isRevealed ? AppTheme.accent.opacity(0.15) : Color.primary.opacity(0.08))
                .frame(width: 44, height: 44)

            Image(systemName: film.isRevealed ? "photo.stack.fill" : "camera.aperture")
                .font(.system(size: 20))
                .foregroundStyle(film.isRevealed ? AppTheme.accent : .secondary)
        }
    }

    private var statusLabel: some View {
        Group {
            if film.isRevealed {
                Label("Revealed", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            } else {
                Label(revealSummary, systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var revealSummary: String {
        let formatted = film.revealAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
        return "Reveals \(formatted)"
    }
}
