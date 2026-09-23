import SwiftUI

/// Drag-to-commit control.
///
/// Used instead of a button for the final step of adding an entry: it takes a
/// deliberate gesture, so a stray tap cannot write a transaction.
struct SwipeToConfirm: View {
    let title: LocalizedStringKey
    let accent: Color
    var enabled: Bool = true
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var offset: CGFloat = 0
    @State private var isConfirming = false
    /// Drives the light tick as the drag passes the commit point.
    @State private var isPastThreshold = false

    private let knob: CGFloat = 54
    private let height: CGFloat = 64
    /// Fraction of the track that must be crossed before it commits.
    private let threshold: CGFloat = 0.72

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - knob - 10)
            let progress = travel > 0 ? offset / travel : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceElevated)

                // The grid is the track. Cells behind the knob burn steadily;
                // the rest only catch the light sweeping across, which gives
                // the bar something to say before the finger arrives.
                DotMatrixTrack(
                    accent: accent,
                    progress: progress,
                    isAnimated: enabled && !reduceMotion && !isConfirming
                )
                .padding(.horizontal, 6)
                .clipShape(.capsule)

                Capsule()
                    .strokeBorder(accent.opacity(0.4 + 0.4 * progress), lineWidth: 1)

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary.opacity(enabled ? 1 - progress * 0.6 : 0.35))
                    // The grid is busy and bright; a plain label sat on it
                    // goes muddy, so it carries its own darkness with it.
                    .shadow(color: .black.opacity(0.8), radius: 5)
                    .shadow(color: .black.opacity(0.5), radius: 12)
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .offset(x: 5 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard enabled, !isConfirming else { return }
                                offset = min(max(0, value.translation.width), travel)
                                isPastThreshold = progress >= threshold
                            }
                            .onEnded { value in
                                guard enabled, !isConfirming else { return }

                                // A fast flick should commit even if the finger
                                // lifted short of the line — judging on position
                                // alone makes a confident gesture feel ignored.
                                let predicted = min(max(0, value.predictedEndTranslation.width), travel)
                                let predictedProgress = travel > 0 ? predicted / travel : 0

                                if progress >= threshold || predictedProgress >= 0.98 {
                                    isConfirming = true
                                    withAnimation(.snappy(duration: 0.18)) { offset = travel }
                                    onConfirm()
                                } else {
                                    isPastThreshold = false
                                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
            .frame(height: height)
        }
        .frame(height: height)
        .opacity(enabled ? 1 : 0.5)
        .sensoryFeedback(.impact(weight: .light), trigger: isPastThreshold) { _, past in past }
        .sensoryFeedback(.success, trigger: isConfirming) { _, confirming in confirming }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint("Swipe right to confirm")
        .accessibilityAddTraits(.isButton)
        // VoiceOver cannot perform the drag, so activation is offered directly.
        .accessibilityAction {
            if enabled { onConfirm() }
        }
        .onChange(of: enabled) { _, isEnabled in
            if !isEnabled { reset() }
        }
    }

    private func reset() {
        isConfirming = false
        offset = 0
    }
}

/// Full-screen confirmation shown after an entry is written.
///
/// The glow grows out of the bottom of the screen — where the swipe control
/// was — rather than appearing all at once, so the confirmation reads as a
/// consequence of the gesture. The label lands only once the wash has
/// established, which is what stops it feeling like a flashcard.
struct SuccessFlash: View {
    let title: LocalizedStringKey
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bloom = false
    @State private var showsLabel = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.45), accent.opacity(0.06)],
                center: UnitPoint(x: 0.5, y: 0.62),
                startRadius: 4,
                endRadius: 560
            )
            .ignoresSafeArea()
            .scaleEffect(bloom ? 1.25 : (reduceMotion ? 1.25 : 0.18), anchor: .bottom)
            .opacity(bloom ? 1 : 0)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolEffect(.bounce, value: showsLabel)
                    .symbolEffectsRemoved(reduceMotion)
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.white)
            .opacity(showsLabel ? 1 : 0)
            .scaleEffect(showsLabel ? 1 : 0.86)
        }
        .onAppear {
            guard !reduceMotion else {
                bloom = true
                showsLabel = true
                return
            }
            // `.smooth` settles without overshoot, which is what a full-screen
            // wash wants — a bouncy spring here reads as a glitch.
            withAnimation(.smooth(duration: 0.5)) { bloom = true }
            withAnimation(.snappy(duration: 0.3).delay(0.3)) { showsLabel = true }
        }
        .accessibilityElement(children: .combine)
    }
}
