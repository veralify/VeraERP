import SwiftUI

/// The card a user just created, shown as a small floating tile.
struct ScatterCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: String
    /// 0...1 — fills the tile's progress bar.
    let fill: Double
    let accent: Color
}

/// Celebration shown once setup is committed.
///
/// The tiles are the user's own income, expenses and debts rather than stock
/// artwork — the point of the screen is "here is what you just built", and
/// placeholder cards would say nothing.
struct SetupSuccessView: View {
    let cards: [ScatterCard]
    let statusText: LocalizedStringKey
    let statusIsGood: Bool
    let targetMonths: Int
    let onContinue: () -> Void

    @State private var hasLanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rotation, offset and depth per position in the stack. Fixed rather than
    /// random so the arrangement is the same every time it is shown.
    private let placements: [(angle: Double, x: CGFloat, y: CGFloat, scale: CGFloat, blur: CGFloat)] = [
        (-8,  -18, -150, 0.80, 5.0),
        (7,    46, -104, 0.86, 3.0),
        (-10, -60,  -36, 0.92, 1.2),
        (5,    40,   38, 0.97, 0.0),
        (-6,  -26,  116, 1.00, 0.0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            cardStack
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text("Setup complete")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Start using Money Manager")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 28)

            Button(action: onContinue) {
                Text("Get started")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(.white, in: .capsule)
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            guard !reduceMotion else {
                hasLanded = true
                return
            }
            withAnimation(.bouncy(duration: 0.75)) { hasLanded = true }
        }
    }

    private var cardStack: some View {
        ZStack {
            // Someone can skip every step. Without a fallback the badges would
            // float in an empty void, which reads as a broken screen rather
            // than a finished one.
            if cards.isEmpty {
                emptyMark
            }

            ForEach(Array(cards.prefix(placements.count).enumerated()), id: \.element.id) { index, card in
                let place = placements[index]
                tile(card)
                    .scaleEffect(place.scale)
                    .rotationEffect(.degrees(place.angle))
                    .offset(x: place.x, y: place.y)
                    // Depth: the tiles behind are softened so the front one reads
                    // as the subject rather than the pile competing for attention.
                    .blur(radius: place.blur)
                    .shadow(color: card.accent.opacity(0.35), radius: 24, y: 10)
                    .opacity(hasLanded ? 1 : 0)
                    .scaleEffect(hasLanded ? 1 : 0.7)
                    .animation(
                        .bouncy(duration: 0.7).delay(Double(index) * 0.06),
                        value: hasLanded
                    )
            }

            if !cards.isEmpty {
                badge(statusText, dot: statusIsGood ? Theme.green : Theme.red)
                    .offset(x: 46, y: -74)
                badge("\(targetMonths) months", dot: Theme.blue)
                    .offset(x: -28, y: 96)
            }
        }
        .frame(height: 400)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Setup complete")
    }

    private var emptyMark: some View {
        VStack(spacing: 14) {
            Text("€")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.lime.readableForeground)
                .frame(width: 96, height: 96)
                .background(Theme.lime, in: .rect(cornerRadius: 28))
                .shadow(color: Theme.lime.opacity(0.35), radius: 28, y: 10)

            Text("Add your income and debts whenever you're ready")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .opacity(hasLanded ? 1 : 0)
        .scaleEffect(hasLanded ? 1 : 0.8)
        .animation(.bouncy(duration: 0.7), value: hasLanded)
    }

    private func tile(_ card: ScatterCard) -> some View {
        let ink = card.accent.readableForeground
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(card.subtitle)
                    .font(.footnote)
                    .foregroundStyle(ink.opacity(0.7))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.opacity(0.25))
                    Capsule()
                        .fill(ink)
                        .frame(width: max(8, geometry.size.width * min(max(card.fill, 0), 1)))
                }
            }
            .frame(height: 5)

            HStack {
                Spacer(minLength: 0)
                Text(card.amount)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.85), in: .capsule)
            }
        }
        .foregroundStyle(ink)
        .padding(14)
        .frame(width: 236, height: 116, alignment: .leading)
        .background(card.accent, in: .rect(cornerRadius: 20))
    }

    private func badge(_ text: LocalizedStringKey, dot: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.88), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
        .opacity(hasLanded ? 1 : 0)
        .scaleEffect(hasLanded ? 1 : 0.8)
        .animation(.bouncy(duration: 0.6).delay(0.34), value: hasLanded)
    }
}
